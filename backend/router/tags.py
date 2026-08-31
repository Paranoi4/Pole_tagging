from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional, List
from datetime import datetime

from config.database import get_db
import models.models as models
import models.schemas as schemas
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
    # ✅ Check if DU belongs to user's org
    du = db.query(models.DistributionUtility).filter(
        models.DistributionUtility.du_id == du_id,
        models.DistributionUtility.org_code == current_user.org_code
    ).first()
    if not du or not du.is_active:
        raise HTTPException(status_code=404, detail="DU not found or inactive")
    
    tags = db.query(models.Tag).filter(
        models.Tag.du_id == du_id,
        models.Tag.status == "Available",
        models.Tag.org_code == current_user.org_code  # ✅ ADD THIS
    ).limit(limit).all()
    
    return tags

# ============================================================
# 2. UPDATE TAG STATUS (Print / Dispatch)
# ============================================================

@router.patch("/{tag_id}/status", response_model=schemas.TagOut)
def update_tag_status(
    tag_id: int,
    status: str = Query(..., pattern="^(Available|Printed|Dispatched|Installed|Lost|Damaged)$"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    tag = db.get(models.Tag, tag_id)
    if not tag:
        raise HTTPException(status_code=404, detail="Tag not found")
    
    # ✅ Check if tag belongs to user's org
    if tag.org_code != current_user.org_code:
        raise HTTPException(status_code=403, detail="You don't have access to this tag")
    
    tag.status = status
    tag.updated_by = current_user.user_id
    tag.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(tag)
    return tag


# ============================================================
# 3. BULK UPDATE STATUS
# ============================================================

@router.patch("/bulk/status")
def bulk_update_status(
    tag_ids: List[int] = Query(..., description="List of tag IDs"),
    status: str = Query(..., pattern="^(Available|Printed|Dispatched|Installed|Lost|Damaged)$"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Bulk update status for multiple tags."""
    if len(tag_ids) > 100:
        raise HTTPException(status_code=400, detail="Maximum 100 tags per bulk update")
    
    # ✅ Add org_code filter
    tags = db.query(models.Tag).filter(
        models.Tag.tag_id.in_(tag_ids),
        models.Tag.org_code == current_user.org_code  # ← ADD THIS!
    ).all()
    
    if len(tags) != len(tag_ids):
        existing_ids = [t.tag_id for t in tags]
        missing = [str(tid) for tid in tag_ids if tid not in existing_ids]
        raise HTTPException(status_code=404, detail=f"Tags not found: {', '.join(missing)}")
    
    for tag in tags:
        tag.status = status
        tag.updated_by = current_user.user_id
        tag.updated_at = datetime.utcnow()
    
    db.commit()
    return {"message": f"Updated {len(tags)} tags to status: {status}"}


# ============================================================
# 4. GET NEXT AVAILABLE TAG
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
        models.Tag.status == "Available",
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
    # ✅ Check DU exists and belongs to user's org
    du = db.query(models.DistributionUtility).filter(
        models.DistributionUtility.du_id == du_id,
        models.DistributionUtility.org_code == current_user.org_code
    ).first()
    if not du:
        raise HTTPException(status_code=404, detail="DU not found")
    
    # ✅ Filter tags by both du_id AND org_code
    total = db.query(models.Tag).filter(
        models.Tag.du_id == du_id,
        models.Tag.org_code == current_user.org_code  # ← ADD THIS
    ).count()
    
    status_counts = {}
    for status in ["Available", "Printed", "Dispatched", "Installed", "Lost", "Damaged"]:
        count = db.query(models.Tag).filter(
            models.Tag.du_id == du_id,
            models.Tag.status == status,
            models.Tag.org_code == current_user.org_code  # ← ADD THIS
        ).count()
        status_counts[status] = count
    
    return {
        "du_id": du_id,
        "du_name": du.du_name,
        "du_code": du.du_code,
        "total_tags": total,
        "status_breakdown": status_counts
    }