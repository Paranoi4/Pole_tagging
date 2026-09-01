from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from typing import Optional, List
from datetime import datetime

from config.database import get_db
import models.models as models
import models.schemas as schemas
from models.enums import (
    RoleName,
    TagStatus,
    BatchStatus,
    BATCH_STATUS_PATTERN,
    AuditEntity,
)
from utils import audit
from utils.auth import get_current_user, require_role

router = APIRouter(prefix="/batches", tags=["Batches"])


# ============================================================
# GENERATE BATCH CODE
# ============================================================

def generate_batch_code(du_code: str, db: Session) -> str:
    """Auto-generate batch code: BT-{DU}-{YEAR}-{SEQ}

    Sequenced from the highest number already issued, not from a row count.
    Counting breaks permanently the first time a batch is deleted: with
    0001-0003 present, removing 0002 leaves a count of 2, so the next create
    proposes 0003 — which still exists — and every attempt after it repeats
    that. Numbers here only ever move up; deleted ones stay as gaps.
    """
    year = datetime.now().year
    prefix = f"BT-{du_code}-{year}-"

    highest = 0
    codes = db.query(models.Batch.batch_code).filter(
        models.Batch.batch_code.like(f"{prefix}%")
    ).all()
    for (code,) in codes:
        suffix = code[len(prefix):]
        if suffix.isdigit():
            highest = max(highest, int(suffix))

    return f"{prefix}{highest + 1:04d}"


# ============================================================
# 1. CREATE BATCH (AUTO-GENERATES CODE)
# ============================================================

# router/batches.py

@router.post("", response_model=schemas.BatchOut, dependencies=[Depends(require_role(RoleName.PRINTERMAN, RoleName.ADMIN))])
def create_batch(
    batch: schemas.BatchCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Create a new batch. Code is auto-generated."""
    
    # ============================================================
    # 1. Check if DU exists AND belongs to user's organization
    # ============================================================
    du = db.query(models.DistributionUtility).filter(
        models.DistributionUtility.du_id == batch.du_id,
        models.DistributionUtility.org_code == current_user.org_code
    ).first()
    
    if not du or not du.is_active:
        raise HTTPException(
            status_code=404, 
            detail="DU not found or inactive in your organization"
        )
    
    # ============================================================
    # 2. Check if Work Order exists AND belongs to the same DU
    # ============================================================
    work_order = db.query(models.WorkOrder).filter(
        models.WorkOrder.work_order_id == batch.work_order_id,
        models.WorkOrder.org_code == current_user.org_code
    ).first()
    
    if not work_order:
        raise HTTPException(status_code=404, detail="Work Order not found")
    
    if work_order.du_id != batch.du_id:
        raise HTTPException(
            status_code=400,
            detail="Work Order does not belong to the selected DU",
        )
    
    # ============================================================
    # 3. Check if there are enough available tags
    # ============================================================
    available_count = db.query(models.Tag).filter(
        models.Tag.du_id == batch.du_id,
        models.Tag.status == TagStatus.AVAILABLE.value,
        models.Tag.batch_id == None,
        models.Tag.org_code == current_user.org_code
    ).count()
    
    if available_count < batch.quantity:
        raise HTTPException(
            status_code=400,
            detail=f"Not enough available tags. Only {available_count} available, requested {batch.quantity}"
        )
    
    # ============================================================
    # 4. Auto-generate batch code
    # ============================================================
    batch_code = generate_batch_code(du.du_code, db)
    
    # ============================================================
    # 5. Create batch with org_code
    # ============================================================
    db_batch = models.Batch(
        du_id=batch.du_id,
        work_order_id=batch.work_order_id,
        batch_code=batch_code,
        quantity=batch.quantity,
        status=BatchStatus.PENDING.value,
        created_by=current_user.user_id,
        org_code=current_user.org_code,
    )
    db.add(db_batch)
    db.flush()
    
    # ============================================================
    # 6. Assign tags to batch (filter by org_code)
    # ============================================================
    tags_to_assign = db.query(models.Tag).filter(
        models.Tag.du_id == batch.du_id,
        models.Tag.status == TagStatus.AVAILABLE.value,
        models.Tag.batch_id == None,
        models.Tag.org_code == current_user.org_code
    ).limit(batch.quantity).all()
    
    # Tags are claimed by the batch but stay "Available" — the print flow
    # (PATCH /tags/{id}/status) is what marks them Printed.
    for tag in tags_to_assign:
        tag.batch_id = db_batch.batch_id
        tag.updated_by = current_user.user_id
        tag.updated_at = datetime.utcnow()

    # from_status is null: the batch did not exist a moment ago. The tags are not
    # logged here — they were claimed, not changed; their status is untouched.
    audit.record(
        db,
        entity_type=AuditEntity.BATCH,
        entity_id=db_batch.batch_id,
        entity_code=db_batch.batch_code,
        org_code=current_user.org_code,
        to_status=BatchStatus.PENDING.value,
        remarks=f"Created with {len(tags_to_assign)} tag IDs",
        performed_by=current_user.user_id,
    )

    # ============================================================
    # 7. Commit and return
    # ============================================================
    try:
        db.commit()
    except IntegrityError as exc:
        # Two printermen creating for the same DU in the same moment compute
        # the same next number; batch_code is unique, so the second loses.
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Another batch was created at the same moment. Please try again.",
        ) from exc
    db.refresh(db_batch)

    return db_batch

# ============================================================
# 2. NEXT BATCH CODE (PREVIEW)
# ============================================================

@router.get("/next-code", response_model=schemas.NextBatchCode)
def get_next_batch_code(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """The code the next batch will be given, for the create form to show.

    Takes no du_id: an organization owns exactly one DU, so the caller's org
    determines it. Uses the same generator as create_batch, so what the form
    displays is what the batch actually gets — computing it client-side meant
    the format lived in two places and could drift apart.

    Still only a preview: another printerman creating a batch first takes the
    number, and create_batch answers that race with a 409.
    """
    du = db.query(models.DistributionUtility).filter(
        models.DistributionUtility.org_code == current_user.org_code,
        models.DistributionUtility.is_active == True,
    ).first()
    if not du:
        raise HTTPException(
            status_code=404,
            detail="No active DU found for your organization",
        )

    return {"next_batch_code": generate_batch_code(du.du_code, db)}


# ============================================================
# 3. MY CURRENT BATCH (the one not yet handed over)
# ============================================================

@router.get("/my-current", response_model=Optional[schemas.BatchOut])
def get_my_current_batch(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """The caller's own batch that has not been dispatched yet.

    Covers Pending *and* Printed, not Pending alone. Printing is what moves a
    batch to Printed, so filtering on Pending made the batch disappear from the
    screen on the next reload — the printerman lost sight of the tags they had
    just printed, and the screen's own green "Printed" badge was unreachable. A
    batch stops being current once it is dispatched, not once it is printed.

    Scoped to created_by, not just the org: two printermen working the same
    shift each need to see the batch they made. Returning the org's newest
    instead would hide one person's work behind the other's, or have both of
    them print the same batch.

    Returns null rather than 404 when there is none — having nothing in hand is
    a normal state, not an error, and the screen shows its empty message for it.
    """
    return (
        db.query(models.Batch)
        .filter(
            models.Batch.org_code == current_user.org_code,
            models.Batch.created_by == current_user.user_id,
            models.Batch.status.in_(
                [BatchStatus.PENDING.value, BatchStatus.PRINTED.value]
            ),
        )
        .order_by(models.Batch.created_at.desc(), models.Batch.batch_id.desc())
        .first()
    )


# ============================================================
# 3. GET ALL BATCHES
# ============================================================

@router.get("", response_model=List[schemas.BatchOut])
def list_batches(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    du_id: Optional[int] = Query(None, description="Filter by DU"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    query = db.query(models.Batch)

    query = query.filter(models.Batch.org_code == current_user.org_code)

    if du_id:
        query = query.filter(models.Batch.du_id == du_id)

    items = query.order_by(models.Batch.created_at.desc()).offset(skip).limit(limit).all()
    return items


# ============================================================
# 3. GET BATCH BY ID
# ============================================================

@router.get("/{batch_id}", response_model=schemas.BatchOut)
def get_batch(
    batch_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Get a single batch by ID."""
    batch = db.query(models.Batch).filter(
        models.Batch.batch_id == batch_id,
        models.Batch.org_code == current_user.org_code,
    ).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")
    return batch


# ============================================================
# 4. GET TAGS IN A BATCH
# ============================================================

@router.get("/{batch_id}/tags", response_model=List[schemas.TagOut])
def get_batch_tags(
    batch_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Get all tags in a batch, in the order they were allocated.

    Ordered explicitly rather than returned off `batch.tags`: the relationship
    has no ordering, so the rows came back in whatever order Postgres produced
    them. Updating a tag's status moved it, which made the print list visibly
    reshuffle after every print or lost-flag.
    """
    batch = db.query(models.Batch).filter(
        models.Batch.batch_id == batch_id,
        models.Batch.org_code == current_user.org_code,
    ).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")

    return (
        db.query(models.Tag)
        .filter(models.Tag.batch_id == batch_id)
        .order_by(models.Tag.tag_id)
        .all()
    )


# ============================================================
# 5. UPDATE BATCH STATUS
# ============================================================

@router.patch("/{batch_id}/status", response_model=schemas.BatchOut)
def update_batch_status(
    batch_id: int,
    status: str = Query(..., pattern=BATCH_STATUS_PATTERN),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Mark a batch printed.

    Deliberately narrow. This used to set any status in any direction with no
    side effects, which let a caller move a dispatched batch back to Printed
    while the crew was still recorded against it, `dispatched_at` still stood,
    and every tag was still Dispatched — four fields describing one fact,
    disagreeing. The batch then reappeared in the dispatch list while a crew was
    physically holding the paper, so the same codes could be handed out twice.

    Dispatching and returning are still perfectly legal transitions; they just
    cannot happen here, because each has to move the tags and the crew with it:

    * Printed -> Dispatched  ->  PATCH /batches/{id}/assign
    * Dispatched -> Printed  ->  PATCH /batches/{id}/return

    Nothing goes backwards from Printed to Pending: paper that has been printed
    cannot be un-printed.
    """
    batch = db.query(models.Batch).filter(
        models.Batch.batch_id == batch_id,
        models.Batch.org_code == current_user.org_code
    ).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")

    # Setting a batch to the status it already holds is a no-op, not an error —
    # a retried request should not fail.
    previous = batch.status

    if status != batch.status:
        if status == BatchStatus.DISPATCHED.value:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Dispatching also assigns a crew and moves the tags. "
                    f"Use PATCH /batches/{batch_id}/assign instead."
                ),
            )

        if batch.status == BatchStatus.DISPATCHED.value:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Returning a dispatched batch also clears its crew and "
                    "moves the tags back. Use "
                    f"PATCH /batches/{batch_id}/return instead."
                ),
            )

        if status == BatchStatus.PENDING.value:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"{batch.batch_code} is {batch.status} and cannot go back "
                    "to Pending — printed tags cannot be un-printed."
                ),
            )

    batch.status = status

    # Only worth an entry when something actually moved; a retried request that
    # sets the status it already holds is not an event.
    if status != previous:
        audit.record(
            db,
            entity_type=AuditEntity.BATCH,
            entity_id=batch.batch_id,
        entity_code=batch.batch_code,
            org_code=current_user.org_code,
            from_status=previous,
            to_status=status,
            performed_by=current_user.user_id,
        )

    db.commit()
    db.refresh(batch)
    return batch


# ============================================================
# 6. DISPATCH BATCH TO CREW
# ============================================================

@router.patch("/{batch_id}/assign", response_model=schemas.BatchOut)
def assign_crew_to_batch(
    batch_id: int,
    crew_id: int = Query(..., description="Crew receiving the batch"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Hand a printed batch to a field crew, or correct which crew holds it.

    Two cases, deliberately on one route because they are the same statement —
    "this crew has this batch":

    * From **Printed** this is the hand-over. The batch *and* every tag in it
      move to Dispatched in one transaction; the tags are what the crew
      physically carries away, so leaving them at Printed while the batch said
      Dispatched meant the two disagreed about who held them. `dispatched_at`
      is stamped here.
    * From **Dispatched** it only corrects the crew. The tags did leave the
      building at the original moment, so `dispatched_at` and the tags' own
      statuses are left exactly as they were — the record of *when* was right,
      only *who* was wrong.

    The crew is checked against the caller's org and against the batch's own DU.
    Both matter: without the org check any crew id in the database could be
    named, and without the DU check a batch could be handed to a crew that works
    poles it will never reach.
    """
    batch = db.query(models.Batch).filter(
        models.Batch.batch_id == batch_id,
        models.Batch.org_code == current_user.org_code
    ).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")

    # A Pending batch is still blank paper — handing over those codes would
    # promise a crew tags that were never printed.
    if batch.status not in (
        BatchStatus.PRINTED.value,
        BatchStatus.DISPATCHED.value,
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                f"Only a Printed or Dispatched batch can be assigned to a crew. "
                f"{batch.batch_code} is {batch.status}."
            ),
        )

    # Matched on crew, org and the batch's DU in one query, so a crew from
    # another organization or another DU reads as "not found" rather than
    # confirming it exists.
    crew = (
        db.query(models.Crew)
        .join(models.City, models.Crew.city_id == models.City.city_id)
        .filter(
            models.Crew.crew_id == crew_id,
            models.Crew.org_code == current_user.org_code,
            models.City.du_id == batch.du_id,
        )
        .first()
    )
    if not crew:
        raise HTTPException(
            status_code=404,
            detail="Crew not found for this batch's DU",
        )

    is_first_handover = batch.status == BatchStatus.PRINTED.value
    previous_crew_id = batch.assigned_crew_id
    previous_status = batch.status

    batch.assigned_crew_id = crew.crew_id

    if is_first_handover:
        batch.status = BatchStatus.DISPATCHED.value
        # Who released it and when, stamped together. A later crew correction
        # leaves both alone: the batch really did leave at that moment, released
        # by that person — only the record of who took it was wrong.
        batch.dispatched_by = current_user.user_id
        batch.dispatched_at = datetime.utcnow()

        # One UPDATE for the whole batch rather than a row at a time: a batch
        # runs to 1000 tags and this is a single hand-over, not a per-tag
        # decision.
        db.query(models.Tag).filter(
            models.Tag.batch_id == batch.batch_id,
            models.Tag.org_code == current_user.org_code,
            models.Tag.status == TagStatus.PRINTED.value,
        ).update(
            {
                models.Tag.status: TagStatus.DISPATCHED.value,
                models.Tag.updated_by: current_user.user_id,
                models.Tag.updated_at: datetime.utcnow(),
            },
            synchronize_session=False,
        )

    # One BATCH entry, not one per tag: the action was on the batch and every tag
    # moved with it. A 1000-tag dispatch would otherwise write 1000 rows saying
    # the same thing. The remark records which of the two things happened, since
    # from/to status is unchanged on a crew correction.
    audit.record(
        db,
        entity_type=AuditEntity.BATCH,
        entity_id=batch.batch_id,
        entity_code=batch.batch_code,
        org_code=current_user.org_code,
        from_status=previous_status,
        to_status=batch.status,
        remarks=(
            f"Dispatched to crew {crew.crew_id} ({crew.crew_label})"
            if is_first_handover
            else f"Crew changed from {previous_crew_id} to {crew.crew_id} "
            f"({crew.crew_label})"
        ),
        performed_by=current_user.user_id,
    )

    db.commit()
    db.refresh(batch)
    return batch


# ============================================================
# 7. RETURN BATCH FROM CREW
# ============================================================

@router.patch("/{batch_id}/return", response_model=schemas.BatchOut)
def return_batch(
    batch_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Take a dispatched batch back off a crew.

    Undoes the whole hand-over rather than just the status: the batch and its
    tags go back to Printed, and the crew, `dispatched_by` and `dispatched_at`
    are all cleared together — those three describe the hand-over currently in
    force, and after a return there is not one. The batch reappears in the
    dispatch list ready to go out again, and a later dispatch stamps fresh
    values.

    Tags a crew has already installed are refused rather than quietly reversed:
    a tag on a pole cannot come back off it by editing a row, so a batch is only
    returnable while none of it has been put up. Tags reported Lost or Damaged
    in the field keep those statuses — the return is about custody of the batch,
    not about rewriting what happened to individual tags.
    """
    batch = db.query(models.Batch).filter(
        models.Batch.batch_id == batch_id,
        models.Batch.org_code == current_user.org_code,
    ).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")

    if batch.status != BatchStatus.DISPATCHED.value:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Only a Dispatched batch can be returned. "
                f"{batch.batch_code} is {batch.status}."
            ),
        )

    installed = db.query(models.Tag).filter(
        models.Tag.batch_id == batch.batch_id,
        models.Tag.org_code == current_user.org_code,
        models.Tag.status == TagStatus.INSTALLED.value,
    ).count()
    if installed:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Cannot return this batch: {installed} of its tags are already "
                "installed on poles."
            ),
        )

    returned_from_crew = batch.assigned_crew_id

    batch.status = BatchStatus.PRINTED.value
    batch.assigned_crew_id = None
    batch.dispatched_by = None
    batch.dispatched_at = None

    db.query(models.Tag).filter(
        models.Tag.batch_id == batch.batch_id,
        models.Tag.org_code == current_user.org_code,
        models.Tag.status == TagStatus.DISPATCHED.value,
    ).update(
        {
            models.Tag.status: TagStatus.PRINTED.value,
            models.Tag.updated_by: current_user.user_id,
            models.Tag.updated_at: datetime.utcnow(),
        },
        synchronize_session=False,
    )

    audit.record(
        db,
        entity_type=AuditEntity.BATCH,
        entity_id=batch.batch_id,
        entity_code=batch.batch_code,
        org_code=current_user.org_code,
        from_status=BatchStatus.DISPATCHED.value,
        to_status=BatchStatus.PRINTED.value,
        remarks=f"Returned from crew {returned_from_crew}",
        performed_by=current_user.user_id,
    )

    db.commit()
    db.refresh(batch)
    return batch


# ============================================================
# 7. DELETE BATCH
# ============================================================


@router.delete("/{batch_id}", dependencies=[Depends(require_role(RoleName.ADMIN))])
def delete_batch(
    batch_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    batch = db.query(models.Batch).filter(
        models.Batch.batch_id == batch_id,
        models.Batch.org_code == current_user.org_code
    ).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")

    # Statuses that record something that happened to the physical tag —
    # printed, taken to the field, put on a pole, lost, damaged. Releasing one of
    # those back to the pool would hand the same code out for a second pole, so a
    # batch holding any of them cannot be deleted.
    #
    # Do Not Use is deliberately not in this set. It records an administrative
    # withdrawal, not a field event, so it must not block deleting an otherwise
    # untouched batch — see the release loop below for how it is handled.
    in_use_statuses = {
        TagStatus.PRINTED.value,
        TagStatus.DISPATCHED.value,
        TagStatus.INSTALLED.value,
        TagStatus.LOST_PRINTED.value,
        TagStatus.DAMAGED.value,
    }
    used = [t for t in batch.tags if t.status in in_use_statuses]
    if used:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Cannot delete this batch: {len(used)} of its tags are already "
                f"in use ({', '.join(sorted({t.status for t in used}))}). "
                "Only a batch whose tags have not been printed can be deleted."
            ),
        )

    # Detach every tag from the batch, but leave the statuses alone. The only two
    # that can be here are Available — already in the pool, nothing to change —
    # and Do Not Use, whose code is withdrawn for good: resetting that to
    # Available would put an unusable code back into circulation, which is
    # exactly what marking it Do Not Use was meant to prevent.
    for tag in batch.tags:
        tag.batch_id = None

    batch_code = batch.batch_code
    released = len(batch.tags)

    # Logged before the delete, and the entry outlives the row it describes —
    # entity_id is a plain column, not a foreign key, precisely so a deleted
    # batch keeps its history.
    audit.record(
        db,
        entity_type=AuditEntity.BATCH,
        entity_id=batch.batch_id,
        entity_code=batch.batch_code,
        org_code=current_user.org_code,
        from_status=batch.status,
        to_status=None,
        remarks=f"Deleted; {released} tag IDs released from the batch",
        performed_by=current_user.user_id,
    )

    db.delete(batch)
    db.commit()
    return {"message": f"Batch {batch_code} deleted successfully"}