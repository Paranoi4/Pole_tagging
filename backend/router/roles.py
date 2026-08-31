from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from typing import List

from config.database import get_db
import models.models as models
import models.schemas as schemas
from models.enums import RoleName
from utils.auth import get_current_user, require_role

router = APIRouter(
    prefix="/roles",
    tags=["Roles"],
    # Base auth only here; Admin check is per-route below so GET stays open
    # to any logged-in user while create/update/delete are Admin-only.
    dependencies=[Depends(get_current_user)],
)


BUILTIN_ROLE_NAMES = {role.value for role in RoleName}


def _reject_if_builtin(role: models.Role, action: str) -> None:
    """The three seeded roles are named directly in every `require_role(...)`
    guard, so renaming or deleting one silently revokes that permission for the
    whole organization — with nobody left holding Admin to undo it."""
    if role.role_name in BUILTIN_ROLE_NAMES:
        raise HTTPException(
            status_code=400,
            detail=(
                f"'{role.role_name}' is a built-in role and cannot be {action}. "
                "Doing so would remove that permission from everyone in your "
                "organization."
            ),
        )


# ===== CREATE ROLE =====
# Admin-only. Roles are fixed (Admin/Printerman/Dispatcher) with no
# "create role" UI, so this being open to any user was pure risk with no
# legitimate use from the frontend.
@router.post("", response_model=schemas.RoleOut, dependencies=[Depends(require_role(RoleName.ADMIN))])
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
    try:
        db.commit()
    except IntegrityError as exc:
        # uq_role_name_org catches what the check above misses when two admins
        # create the same role name at the same moment.
        db.rollback()
        raise HTTPException(status_code=400, detail="Role already exists") from exc
    db.refresh(db_role)
    return db_role


# ===== GET ALL ROLES =====
@router.get("", response_model=List[schemas.RoleOut], dependencies=[Depends(require_role(RoleName.ADMIN))])
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
@router.get("/{role_id}", response_model=schemas.RoleOut, dependencies=[Depends(require_role(RoleName.ADMIN))])
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
@router.put("/{role_id}", response_model=schemas.RoleOut, dependencies=[Depends(require_role(RoleName.ADMIN))])
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

    _reject_if_builtin(role, "renamed")

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

    try:
        db.commit()
    except IntegrityError as exc:
        # Same check-then-write race as create_role.
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail="Role already exists in this organization",
        ) from exc
    db.refresh(role)
    return role

# ===== DELETE ROLE =====
@router.delete("/{role_id}", dependencies=[Depends(require_role(RoleName.ADMIN))])
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

    _reject_if_builtin(role, "deleted")

    db.delete(role)
    db.commit()
    return {"message": "Role deleted"}