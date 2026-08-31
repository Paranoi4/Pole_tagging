from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List

from config.database import get_db
import models.models as models
import models.schemas as schemas
from utils.auth import get_current_user, require_role

router = APIRouter(
    prefix="/roles",
    tags=["Roles"],
    # Base auth only here; Admin check is per-route below so GET stays open
    # to any logged-in user while create/update/delete are Admin-only.
    dependencies=[Depends(get_current_user)],
)


# ===== CREATE ROLE =====
# Admin-only. Roles are fixed (Admin/Printerman/Dispatcher) with no
# "create role" UI, so this being open to any user was pure risk with no
# legitimate use from the frontend.
@router.post("", response_model=schemas.RoleOut, dependencies=[Depends(require_role("Admin"))])
def create_role(
    role: schemas.RoleCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if db.query(models.Role).filter(
        models.Role.role_name == role.role_name,
        models.Role.org_code == current_user.org_code
    ).first():
        raise HTTPException(status_code=400, detail="Role already exists")
    
    db_role = models.Role(
        **role.model_dump(),
        org_code=current_user.org_code
    )
    db.add(db_role)
    db.commit()
    db.refresh(db_role)
    return db_role


# ===== GET ALL ROLES =====
@router.get("", response_model=List[schemas.RoleOut], dependencies=[Depends(require_role("Admin"))])
def list_roles(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    return db.query(models.Role).filter(
        models.Role.org_code == current_user.org_code
    ).offset(skip).limit(limit).all()


# ===== GET ROLE BY ID =====
@router.get("/{role_id}", response_model=schemas.RoleOut, dependencies=[Depends(require_role("Admin"))])
def get_role(
    role_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Admin can ONLY get roles from their organization."""
    role = db.query(models.Role).filter(
        models.Role.role_id == role_id,
        models.Role.org_code == current_user.org_code
    ).first()
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    return role


# ===== UPDATE ROLE =====
@router.put("/{role_id}", response_model=schemas.RoleOut, dependencies=[Depends(require_role("Admin"))])
def update_role(
    role_id: int,
    patch: schemas.RoleUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    role = db.query(models.Role).filter(
        models.Role.role_id == role_id,
        models.Role.org_code == current_user.org_code
    ).first()
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    
    data = patch.model_dump(exclude_unset=True)
    
    if data.get("role_name") and data["role_name"] != role.role_name:
        if db.query(models.Role).filter(
            models.Role.role_name == data["role_name"],
            models.Role.org_code == current_user.org_code
        ).first():
            raise HTTPException(status_code=400, detail="Role already exists in this organization")
    
    for field, value in data.items():
        if value is not None:
            setattr(role, field, value)
    
    db.commit()
    db.refresh(role)
    return role

# ===== DELETE ROLE =====
@router.delete("/{role_id}", dependencies=[Depends(require_role("Admin"))])
def delete_role(
    role_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    role = db.query(models.Role).filter(
        models.Role.role_id == role_id,
        models.Role.org_code == current_user.org_code
    ).first()
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    
    db.delete(role)
    db.commit()
    return {"message": "Role deleted"}