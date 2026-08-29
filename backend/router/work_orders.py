from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional, List
from datetime import datetime

from config.database import get_db
import models.models as models
import models.schemas as schemas
from utils.auth import get_current_user, require_role

router = APIRouter(prefix="/work-orders", tags=["Work Orders"])


# ============================================================
# GENERATE WORK ORDER CODE
# ============================================================

def generate_work_order_code(du_code: str, db: Session) -> str:
    """Auto-generate work order code: WO-{DU}-{YEAR}-{SEQ}"""
    year = datetime.now().year
    
    # Count existing work orders for this DU this year
    count = db.query(models.WorkOrder).filter(
        models.WorkOrder.du.has(du_code=du_code),
        models.WorkOrder.work_order_code.like(f"WO-{du_code}-{year}-%")
    ).count() + 1
    
    return f"WO-{du_code}-{year}-{count:04d}"


# ============================================================
# 1. CREATE WORK ORDER (AUTO-GENERATES CODE)
# ============================================================

@router.post("", response_model=schemas.WorkOrderOut, dependencies=[Depends(require_role("Admin"))])
def create_work_order(
    work_order: schemas.WorkOrderCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Create a new Work Order. Code is auto-generated."""
    
    # ============================================================
    # 1. Check if DU exists AND belongs to user's organization
    # ============================================================
    du = db.query(models.DistributionUtility).filter(
        models.DistributionUtility.du_id == work_order.du_id,
        models.DistributionUtility.org_code == current_user.org_code  # ✅ org_code check
    ).first()
    
    if not du or not du.is_active:
        raise HTTPException(
            status_code=404, 
            detail="DU not found or inactive in your organization"
        )
    
    # ============================================================
    # 2. Auto-generate work order code
    # ============================================================
    work_order_code = generate_work_order_code(du.du_code, db)
    
    # Check if code already exists (shouldn't happen with unique generation)
    if db.query(models.WorkOrder).filter(
        models.WorkOrder.work_order_code == work_order_code
    ).first():
        raise HTTPException(status_code=400, detail="Work Order code already exists")
    
    # ============================================================
    # 3. Create work order with org_code
    # ============================================================
    db_work_order = models.WorkOrder(
        du_id=work_order.du_id,
        work_order_name=work_order.work_order_name,
        work_order_code=work_order_code,
        description=work_order.description,
        created_by=current_user.user_id,
        org_code=current_user.org_code,  # ✅ ADD THIS
    )
    db.add(db_work_order)
    db.commit()
    db.refresh(db_work_order)
    
    return db_work_order


# ============================================================
# 2. GET ALL WORK ORDERS
# ============================================================

@router.get("", response_model=List[schemas.WorkOrderOut])
def list_work_orders(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    du_id: Optional[int] = Query(None, description="Filter by DU"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """List all Work Orders for the current org."""
    query = db.query(models.WorkOrder).filter(
        models.WorkOrder.org_code == current_user.org_code
    )

    if du_id:
        query = query.filter(models.WorkOrder.du_id == du_id)

    items = query.order_by(models.WorkOrder.created_at.desc()).offset(skip).limit(limit).all()
    return items


# ============================================================
# 3. GET WORK ORDER BY ID
# ============================================================

@router.get("/{work_order_id}", response_model=schemas.WorkOrderOut)
def get_work_order(
    work_order_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Get a single Work Order by ID."""
    work_order = db.query(models.WorkOrder).filter(
        models.WorkOrder.work_order_id == work_order_id,
        models.WorkOrder.org_code == current_user.org_code,
    ).first()
    if not work_order:
        raise HTTPException(status_code=404, detail="Work Order not found")
    return work_order


# ============================================================
# 4. UPDATE WORK ORDER
# ============================================================

@router.put("/{work_order_id}", response_model=schemas.WorkOrderOut, dependencies=[Depends(require_role("Admin"))])
def update_work_order(
    work_order_id: int,
    patch: schemas.WorkOrderUpdate,
    db: Session = Depends(get_db),
):
    """Update a Work Order."""
    work_order = db.get(models.WorkOrder, work_order_id)
    if not work_order:
        raise HTTPException(status_code=404, detail="Work Order not found")
    
    data = patch.model_dump(exclude_unset=True)
    
    for field, value in data.items():
        if value is not None:
            setattr(work_order, field, value)
    
    db.commit()
    db.refresh(work_order)
    return work_order


# ============================================================
# 5. DELETE WORK ORDER
# ============================================================

@router.delete("/{work_order_id}", dependencies=[Depends(require_role("Admin"))])
def delete_work_order(
    work_order_id: int,
    db: Session = Depends(get_db),
):
    """Delete a Work Order."""
    work_order = db.get(models.WorkOrder, work_order_id)
    if not work_order:
        raise HTTPException(status_code=404, detail="Work Order not found")
    
    db.delete(work_order)
    db.commit()
    return {"message": "Work Order deleted successfully"}