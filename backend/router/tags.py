from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional, List
from datetime import datetime

from config.database import get_db
import models.models as models
import models.schemas as schemas
from models.enums import (
    TagStatus,
    TAG_STATUS_PATTERN,
    STATUSES_REQUIRING_REMARKS,
    UNREACHABLE_TAG_STATUSES,
    FORBIDDEN_TAG_TRANSITIONS,
    PRINTABLE_TAG_STATUSES,
    AuditEntity,
)
from utils import audit
from utils.auth import get_current_user, require_role

router = APIRouter(prefix="/tags", tags=["Tags"])


# ============================================================
# 1. GET AVAILABLE TAGS FOR DU
# ============================================================

@router.get("/available/{du_id}", response_model=List[schemas.TagOut])
def get_available_tags(
    du_id: int,
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    du = db.query(models.DistributionUtility).filter(
        models.DistributionUtility.du_id == du_id,
        models.DistributionUtility.org_code == current_user.org_code
    ).first()
    if not du or not du.is_active:
        raise HTTPException(status_code=404, detail="DU not found or inactive")
    
    tags = db.query(models.Tag).filter(
        models.Tag.du_id == du_id,
        models.Tag.status == TagStatus.AVAILABLE.value,
        models.Tag.org_code == current_user.org_code
    ).limit(limit).all()
    
    return tags

# ============================================================
# 2. BULK UPDATE STATUS
# ============================================================
# Declared before `/{tag_id}/status` on purpose. Routes are matched in
# declaration order, so with the parameterized route first, a request to
# /tags/bulk/status matches it with tag_id="bulk", fails int validation, and
# returns 422 — the bulk handler is never reached. Keep static paths above
# parameterized ones that would otherwise swallow them.

@router.patch("/bulk/status")
def bulk_update_status(
    tag_ids: List[int] = Query(..., description="List of tag IDs"),
    status: str = Query(..., pattern=TAG_STATUS_PATTERN),
    remarks: Optional[str] = Query(
        None,
        max_length=1000,
        description="Why the status changed, recorded on every tag in the call",
    ),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Bulk update status for multiple tags.

    `remarks` records why the status changed. It is **required** for the statuses
    that withdraw a tag from use — Lost Printed and Do Not Use — because a code
    written off with no reason behind it cannot be accounted for later. Enforced
    here rather than in a screen, so every caller obeys the same rule.

    For any other status it is optional, and omitting it leaves each tag's
    existing remark alone rather than blanking it — a reprint must not erase the
    note explaining an earlier loss.
    """
    if len(tag_ids) > 100:
        raise HTTPException(status_code=400, detail="Maximum 100 tags per bulk update")

    if status in STATUSES_REQUIRING_REMARKS and not (remarks or "").strip():
        raise HTTPException(
            status_code=400,
            detail=f"A reason is required when marking a tag {status}.",
        )

    if status in UNREACHABLE_TAG_STATUSES:
        raise HTTPException(
            status_code=400,
            detail=f"Setting a tag to {status} is not supported yet.",
        )

    tags = db.query(models.Tag).filter(
        models.Tag.tag_id.in_(tag_ids),
        models.Tag.org_code == current_user.org_code
    ).all()

    if len(tags) != len(tag_ids):
        existing_ids = [t.tag_id for t in tags]
        missing = [str(tid) for tid in tag_ids if tid not in existing_ids]
        raise HTTPException(status_code=404, detail=f"Tags not found: {', '.join(missing)}")

    # Checked against each tag's current status, and refused for the whole call
    # rather than per tag: a bulk update that silently skipped some of its ids
    # would leave the caller thinking every tag moved.
    refused: dict[str, list[str]] = {}
    for tag in tags:
        reason = FORBIDDEN_TAG_TRANSITIONS.get((tag.status, status))

        # Reaching Printed means the code went onto paper, and only a code that
        # was owed paper can do that. Without this a withdrawn Do Not Use code
        # could be printed simply by naming Printed directly — the print sheet
        # filters it out, but the endpoint is reachable from anywhere.
        if (
            reason is None
            and status == TagStatus.PRINTED.value
            and tag.status not in PRINTABLE_TAG_STATUSES
        ):
            reason = f"a {tag.status} tag is not waiting to be printed"

        if reason:
            refused.setdefault(reason, []).append(tag.tag_code)
    if refused:
        detail = "; ".join(
            f"{', '.join(sorted(codes))} ({reason})" for reason, codes in refused.items()
        )
        raise HTTPException(
            status_code=400,
            detail=f"Cannot set {status}: {detail}.",
        )

    # Captured before the loop overwrites them — the audit entry needs where each
    # tag came from, and a bulk call can start from a mix of statuses.
    audit_changes = [(tag.tag_id, tag.tag_code, tag.status) for tag in tags]

    for tag in tags:
        tag.status = status
        if remarks is not None:
            tag.remarks = remarks
        tag.updated_by = current_user.user_id
        tag.updated_at = datetime.utcnow()

    # One entry per tag: each was individually chosen by whoever ticked it.
    audit.record_many(
        db,
        entity_type=AuditEntity.TAG,
        changes=audit_changes,
        org_code=current_user.org_code,
        to_status=status,
        remarks=remarks,
        performed_by=current_user.user_id,
    )

    db.commit()
    return {"message": f"Updated {len(tags)} tags to status: {status}"}


# ============================================================
# 3. GET NEXT AVAILABLE TAG
# ============================================================

@router.get("/next/{du_id}")
def get_next_available_tag(
    du_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Get the next available tag for a DU."""
    # Check DU exists and belongs to user's org
    du = db.query(models.DistributionUtility).filter(
        models.DistributionUtility.du_id == du_id,
        models.DistributionUtility.org_code == current_user.org_code
    ).first()
    if not du or not du.is_active:
        raise HTTPException(status_code=404, detail="DU not found or inactive")
    
    # Get next available tag for this DU in the user's org
    tag = db.query(models.Tag).filter(
        models.Tag.du_id == du_id,
        models.Tag.status == TagStatus.AVAILABLE.value,
        models.Tag.org_code == current_user.org_code
    ).order_by(models.Tag.tag_id).first()
    
    if not tag:
        return {"message": "No available tags for this DU", "tag": None}
    
    return {
        "tag_id": tag.tag_id,
        "tag_code": tag.tag_code,
        "pole_no": tag.pole_no
    }

# ============================================================
# 5. GET TAG STATISTICS
# ============================================================

@router.get("/stats/{du_id}")
def get_tag_stats(
    du_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Get tag statistics for a DU."""
    du = db.query(models.DistributionUtility).filter(
        models.DistributionUtility.du_id == du_id,
        models.DistributionUtility.org_code == current_user.org_code
    ).first()
    if not du:
        raise HTTPException(status_code=404, detail="DU not found")
    
    total = db.query(models.Tag).filter(
        models.Tag.du_id == du_id,
        models.Tag.org_code == current_user.org_code
    ).count()
    
    status_counts = {}
    for status in (member.value for member in TagStatus):
        count = db.query(models.Tag).filter(
            models.Tag.du_id == du_id,
            models.Tag.status == status,
            models.Tag.org_code == current_user.org_code
        ).count()
        status_counts[status] = count
    
    return {
        "du_id": du_id,
        "du_name": du.du_name,
        "du_code": du.du_code,
        "total_tags": total,
        "status_breakdown": status_counts
    }