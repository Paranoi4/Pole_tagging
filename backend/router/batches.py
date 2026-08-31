from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from typing import Optional, List
from datetime import datetime

from config.database import get_db
import models.models as models
import models.schemas as schemas
from models.enums import RoleName, TagStatus, BatchStatus, BATCH_STATUS_PATTERN
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
        assigned_to=batch.assigned_to,
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
    """Get all tags in a batch."""
    batch = db.query(models.Batch).filter(
        models.Batch.batch_id == batch_id,
        models.Batch.org_code == current_user.org_code,
    ).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")

    return batch.tags


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
    batch = db.query(models.Batch).filter(
        models.Batch.batch_id == batch_id,
        models.Batch.org_code == current_user.org_code
    ).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")
    
    batch.status = status
    db.commit()
    db.refresh(batch)
    return batch


# ============================================================
# 6. ASSIGN CREW TO BATCH
# ============================================================

@router.patch("/{batch_id}/assign", response_model=schemas.BatchOut)
def assign_crew_to_batch(
    batch_id: int,
    assigned_to: int = Query(..., description="User ID of field crew"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    batch = db.query(models.Batch).filter(
        models.Batch.batch_id == batch_id,
        models.Batch.org_code == current_user.org_code
    ).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")
    
    batch.assigned_to = assigned_to
    batch.status = BatchStatus.DISPATCHED.value
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

    # Tags that left "Available" record something that happened in the field —
    # printed, dispatched, installed on a pole. Releasing those back to the pool
    # would hand the same code out for a second pole, so a batch is only
    # deletable while none of its tags have been used yet.
    used = [t for t in batch.tags if t.status != TagStatus.AVAILABLE.value]
    if used:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Cannot delete this batch: {len(used)} of its tags are already "
                f"in use ({', '.join(sorted({t.status for t in used}))}). "
                "Only a batch whose tags are all still Available can be deleted."
            ),
        )

    # Release the untouched tags back to the available pool.
    for tag in batch.tags:
        tag.batch_id = None
        tag.status = TagStatus.AVAILABLE.value

    batch_code = batch.batch_code
    db.delete(batch)
    db.commit()
    return {"message": f"Batch {batch_code} deleted successfully"}