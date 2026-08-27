from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional, List

from config.database import get_db
import models.models as models
import models.schemas as schemas
from utils.auth import get_current_user, require_role
from utils.tag_encoding import generate_all_tags_for_du

router = APIRouter(
    prefix="/du",
    tags=["Distribution Utilities"],
)


# ============================================================
# 1. CREATE DU (AUTO-GENERATES ALL 1,048,575 TAGS WITH PREFIX)
# ============================================================

@router.post("", response_model=schemas.DUOut, dependencies=[Depends(require_role("Admin"))])
def create_du(
    du: schemas.DUCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Create a new DU and auto-generate ALL 1,048,575 tags with DU prefix."""
    
    # Check if DU code already exists
    if db.query(models.DistributionUtility).filter(
        models.DistributionUtility.du_code == du.du_code
    ).first():
        raise HTTPException(status_code=400, detail="DU code already exists")
    
    # Check if DU name already exists
    if db.query(models.DistributionUtility).filter(
        models.DistributionUtility.du_name == du.du_name
    ).first():
        raise HTTPException(status_code=400, detail="DU name already exists")
    
    # Create DU
    db_du = models.DistributionUtility(
        du_name=du.du_name,
        du_code=du.du_code,
        created_by=current_user.user_id,
    )
    db.add(db_du)
    db.flush()  # Get du_id without committing
    
    # ============================================================
    # 🔥 AUTO-GENERATE ALL 1,048,575 TAGS WITH DU PREFIX
    # ============================================================
    tags = generate_all_tags_for_du(db_du.du_id, db_du.du_code)
    db.bulk_insert_mappings(models.Tag, tags)
    # ============================================================
    
    db.commit()
    db.refresh(db_du)
    
    return {
        **schemas.DUOut.model_validate(db_du).model_dump(),
        "tags_generated": len(tags),
        "message": f"DU created with {len(tags):,} pre-generated tags"
    }


# ============================================================
# 2. GET ALL DUS
# ============================================================

@router.get("", response_model=List[schemas.DUOut])
def list_dus(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100),
    include_inactive: bool = Query(False),
    search: Optional[str] = Query(None, description="Search by name or code"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """List all Distribution Utilities."""
    query = db.query(models.DistributionUtility)
    
    if not include_inactive:
        query = query.filter(models.DistributionUtility.is_active == True)
    
    if search:
        search_pattern = f"%{search}%"
        query = query.filter(
            models.DistributionUtility.du_name.ilike(search_pattern) |
            models.DistributionUtility.du_code.ilike(search_pattern)
        )
    
    items = query.order_by(models.DistributionUtility.du_name).offset(skip).limit(limit).all()
    return items


# ============================================================
# 3. GET DU BY ID
# ============================================================

@router.get("/{du_id}", response_model=schemas.DUOut)
def get_du(
    du_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Get a single DU by ID."""
    du = db.get(models.DistributionUtility, du_id)
    if not du:
        raise HTTPException(status_code=404, detail="DU not found")
    return du


# ============================================================
# 4. GET DU WITH TAG STATISTICS
# ============================================================

@router.get("/{du_id}/stats", response_model=schemas.DUWithStats)
def get_du_with_stats(
    du_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Get DU with tag statistics."""
    du = db.get(models.DistributionUtility, du_id)
    if not du:
        raise HTTPException(status_code=404, detail="DU not found")
    
    total = db.query(models.Tag).filter(models.Tag.du_id == du_id).count()
    available = db.query(models.Tag).filter(
        models.Tag.du_id == du_id,
        models.Tag.status == "Available"
    ).count()
    printed = db.query(models.Tag).filter(
        models.Tag.du_id == du_id,
        models.Tag.status == "Printed"
    ).count()
    dispatched = db.query(models.Tag).filter(
        models.Tag.du_id == du_id,
        models.Tag.status == "Dispatched"
    ).count()
    
    return {
        **schemas.DUOut.model_validate(du).model_dump(),
        "tags_count": total,
        "available_count": available,
        "printed_count": printed,
        "dispatched_count": dispatched,
    }


# ============================================================
# 5. UPDATE DU
# ============================================================

@router.put("/{du_id}", response_model=schemas.DUOut, dependencies=[Depends(require_role("Admin"))])
def update_du(
    du_id: int,
    patch: schemas.DUUpdate,
    db: Session = Depends(get_db),
):
    """Update a DU."""
    du = db.get(models.DistributionUtility, du_id)
    if not du:
        raise HTTPException(status_code=404, detail="DU not found")
    
    data = patch.model_dump(exclude_unset=True)
    
    if data.get("du_code") and data["du_code"] != du.du_code:
        if db.query(models.DistributionUtility).filter(
            models.DistributionUtility.du_code == data["du_code"]
        ).first():
            raise HTTPException(status_code=400, detail="DU code already exists")
    
    if data.get("du_name") and data["du_name"] != du.du_name:
        if db.query(models.DistributionUtility).filter(
            models.DistributionUtility.du_name == data["du_name"]
        ).first():
            raise HTTPException(status_code=400, detail="DU name already exists")
    
    for field, value in data.items():
        if value is not None:
            setattr(du, field, value)
    
    db.commit()
    db.refresh(du)
    return du


# ============================================================
# 6. DELETE DU (HARD DELETE - DELETES ALL TAGS)
# ============================================================

@router.delete("/{du_id}", dependencies=[Depends(require_role("Admin"))])
def delete_du(
    du_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    DELETE a DU and ALL its tags (Hard Delete).
    
    ⚠️ WARNING: This action cannot be undone!
    """
    
    du = db.get(models.DistributionUtility, du_id)
    if not du:
        raise HTTPException(status_code=404, detail="DU not found")
    
    tags_count = db.query(models.Tag).filter(models.Tag.du_id == du_id).count()
    
    du_name = du.du_name
    du_code = du.du_code
    
    # This will delete all tags automatically due to CASCADE
    db.delete(du)
    db.commit()
    
    return {
        "message": f"DU '{du_name}' ({du_code}) deleted successfully",
        "du_id": du_id,
        "du_name": du_name,
        "du_code": du_code,
        "tags_deleted": tags_count,
        "deleted_by": current_user.username
    }


# ============================================================
# 7. SOFT DELETE DU (Deactivate)
# ============================================================

@router.patch("/{du_id}/deactivate", dependencies=[Depends(require_role("Admin"))])
def deactivate_du(
    du_id: int,
    db: Session = Depends(get_db),
):
    """SOFT DELETE a DU (Just deactivates it, tags remain)."""
    du = db.get(models.DistributionUtility, du_id)
    if not du:
        raise HTTPException(status_code=404, detail="DU not found")
    
    if not du.is_active:
        raise HTTPException(status_code=400, detail="DU is already deactivated")
    
    du.is_active = False
    db.commit()
    db.refresh(du)
    
    return {
        "message": f"DU '{du.du_name}' ({du.du_code}) deactivated successfully",
        "du_id": du_id,
        "du_name": du.du_name,
        "du_code": du.du_code,
        "is_active": False
    }


# ============================================================
# 8. REACTIVATE DU
# ============================================================

@router.patch("/{du_id}/reactivate", response_model=schemas.DUOut, dependencies=[Depends(require_role("Admin"))])
def reactivate_du(
    du_id: int,
    db: Session = Depends(get_db),
):
    """Reactivate a deactivated DU."""
    du = db.get(models.DistributionUtility, du_id)
    if not du:
        raise HTTPException(status_code=404, detail="DU not found")
    
    if du.is_active:
        raise HTTPException(status_code=400, detail="DU is already active")
    
    du.is_active = True
    db.commit()
    db.refresh(du)
    return du