from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional, List
from datetime import datetime

from config.database import get_db
import models.models as models
import models.schemas as schemas
from utils.auth import get_current_user, require_role

router = APIRouter(prefix="/batches", tags=["Batches"])


# ============================================================
# GENERATE BATCH CODE
# ============================================================

def generate_batch_code(du_code: str, db: Session) -> str:
    """Auto-generate batch code: BT-{DU}-{YEAR}-{SEQ}"""
    year = datetime.now().year
    
    # Count existing batches for this DU this year
    count = db.query(models.Batch).filter(
        models.Batch.du.has(du_code=du_code),
        models.Batch.batch_code.like(f"BT-{du_code}-{year}-%")
    ).count() + 1
    
    return f"BT-{du_code}-{year}-{count:04d}"


# ============================================================
# 1. CREATE BATCH (AUTO-GENERATES CODE)
# ============================================================

# router/batches.py

@router.post("", response_model=schemas.BatchOut, dependencies=[Depends(require_role("Printerman", "Admin"))])
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
        models.DistributionUtility.org_code == current_user.org_code  # ✅ org_code check
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
        models.WorkOrder.org_code == current_user.org_code  # ✅ org_code check
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
        models.Tag.status == "Available",
        models.Tag.batch_id == None,
        models.Tag.org_code == current_user.org_code  # ✅ org_code check
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
        status="Pending",
        assigned_to=batch.assigned_to,
        created_by=current_user.user_id,
        org_code=current_user.org_code,  # ✅ ADD THIS
    )
    db.add(db_batch)
    db.flush()
    
    # ============================================================
    # 6. Assign tags to batch (filter by org_code)
    # ============================================================
    tags_to_assign = db.query(models.Tag).filter(
        models.Tag.du_id == batch.du_id,
        models.Tag.status == "Available",
        models.Tag.batch_id == None,
        models.Tag.org_code == current_user.org_code  # ✅ org_code check
    ).limit(batch.quantity).all()
    
    for tag in tags_to_assign:
        tag.batch_id = db_batch.batch_id
        # tag.status = "Printed"  # ← COMMENTED OUT for print button flow
        tag.updated_by = current_user.user_id
        tag.updated_at = datetime.utcnow()
    
    # ============================================================
    # 7. Commit and return
    # ============================================================
    db.commit()
    db.refresh(db_batch)
    
    return db_batch

# ============================================================
# 2. GET ALL BATCHES
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
    status: str = Query(..., pattern="^(Pending|Printed|Dispatched)$"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    batch = db.query(models.Batch).filter(
        models.Batch.batch_id == batch_id,
        models.Batch.org_code == current_user.org_code  # ← ADD THIS
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
        models.Batch.org_code == current_user.org_code  # ← ADD THIS
    ).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")
    
    batch.assigned_to = assigned_to
    batch.status = "Dispatched"
    db.commit()
    db.refresh(batch)
    return batch


# ============================================================
# 7. DELETE BATCH
# ============================================================


@router.delete("/{batch_id}", dependencies=[Depends(require_role("Admin"))])
def delete_batch(
    batch_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),  # ← ADD THIS
):
    batch = db.query(models.Batch).filter(
        models.Batch.batch_id == batch_id,
        models.Batch.org_code == current_user.org_code  # ← ADD THIS
    ).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")
    
    # Release tags back to available pool
    for tag in batch.tags:
        tag.batch_id = None
        tag.status = "Available"
    
    db.delete(batch)
    db.commit()
    return {"message": f"Batch {batch.batch_code} deleted successfully"}