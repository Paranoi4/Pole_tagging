from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from typing import Optional, List
from datetime import datetime

from config.database import get_db
import models.models as models
import models.schemas as schemas
from models.enums import RoleName
from utils.auth import get_current_user, require_role

router = APIRouter(prefix="/work-orders", tags=["Work Orders"])


# ============================================================
# GENERATE WORK ORDER CODE
# ============================================================

def generate_work_order_code(du_code: str, db: Session) -> str:
    """Auto-generate work order code: WO-{DU}-{YEAR}-{SEQ}

    Sequenced from the highest number already issued, not from a row count.
    Counting breaks permanently the first time a work order is deleted: with
    0001-0003 present, removing 0002 leaves a count of 2, so the next create
    proposes 0003 — which still exists — and every attempt after it repeats
    that. Numbers here only ever move up; deleted ones stay as gaps.
    """
    year = datetime.now().year
    prefix = f"WO-{du_code}-{year}-"

    highest = 0
    codes = db.query(models.WorkOrder.work_order_code).filter(
        models.WorkOrder.work_order_code.like(f"{prefix}%")
    ).all()
    for (code,) in codes:
        suffix = code[len(prefix):]
        if suffix.isdigit():
            highest = max(highest, int(suffix))

    return f"{prefix}{highest + 1:04d}"


# ============================================================
# 1. CREATE WORK ORDER (AUTO-GENERATES CODE)
# ============================================================

@router.post("", response_model=schemas.WorkOrderOut, dependencies=[Depends(require_role(RoleName.ADMIN))])
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
        models.DistributionUtility.org_code == current_user.org_code
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
        org_code=current_user.org_code,
    )
    db.add(db_work_order)
    try:
        db.commit()
    except IntegrityError as exc:
        # Two admins creating for the same DU in the same moment compute the
        # same next number; work_order_code is unique, so the second loses.
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Another work order was created at the same moment. Please try again.",
        ) from exc
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

@router.put("/{work_order_id}", response_model=schemas.WorkOrderOut, dependencies=[Depends(require_role(RoleName.ADMIN))])
def update_work_order(
    work_order_id: int,
    patch: schemas.WorkOrderUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    work_order = db.query(models.WorkOrder).filter(
        models.WorkOrder.work_order_id == work_order_id,
        models.WorkOrder.org_code == current_user.org_code
    ).first()
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

@router.delete("/{work_order_id}", dependencies=[Depends(require_role(RoleName.ADMIN))])
def delete_work_order(
    work_order_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    work_order = db.query(models.WorkOrder).filter(
        models.WorkOrder.work_order_id == work_order_id,
        models.WorkOrder.org_code == current_user.org_code
    ).first()
    if not work_order:
        raise HTTPException(status_code=404, detail="Work Order not found")
    
    db.delete(work_order)
    db.commit()
    return {"message": "Work Order deleted successfully"}