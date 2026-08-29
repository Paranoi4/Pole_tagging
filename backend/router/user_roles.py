from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from config.database import get_db
import models.models as models
import models.schemas as schemas
from utils.auth import get_current_user, require_role

router = APIRouter(
    prefix="/user-roles",
    tags=["User Roles"],
    # Base auth only here; the Admin check is applied per-route below so
    # this router's dependency list stays a single source of truth for
    # "must be logged in", while "must be Admin" is explicit per-endpoint.
    dependencies=[Depends(get_current_user)],
)


# ===== ASSIGN ROLE TO USER =====
@router.post("", response_model=schemas.UserRoleOut, dependencies=[Depends(require_role("Admin"))])
def assign_role_to_user(
    payload: schemas.UserRoleCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),  # ✅ ADD THIS
):
    # Check if user exists AND belongs to same org
    user = db.query(models.User).filter(
        models.User.user_id == payload.user_id,
        models.User.org_code == current_user.org_code  # ✅ ADD THIS
    ).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Check if role exists AND belongs to same org
    role = db.query(models.Role).filter(
        models.Role.role_id == payload.role_id,
        models.Role.org_code == current_user.org_code  # ✅ ADD THIS
    ).first()
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    
    # Check if already assigned
    existing = db.query(models.UserRole).filter(
        models.UserRole.user_id == payload.user_id,
        models.UserRole.role_id == payload.role_id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Role already assigned to user")
    
    db_user_role = models.UserRole(
        **payload.model_dump(),
        org_code=current_user.org_code  # ✅ ADD THIS
    )
    db.add(db_user_role)
    db.commit()
    db.refresh(db_user_role)
    
    return schemas.UserRoleOut.model_validate(db_user_role)


# A user's roles are already returned by GET /users/{id} and by the login
# response, so this router only covers assigning and removing.


# ===== REMOVE ROLE FROM USER BY USER AND ROLE ID =====
@router.delete("/user/{user_id}/role/{role_id}", dependencies=[Depends(require_role("Admin"))])
def remove_role_by_ids(
    user_id: int,
    role_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Admin can ONLY remove roles from users in their organization."""
    user_role = db.query(models.UserRole).filter(
        models.UserRole.user_id == user_id,
        models.UserRole.role_id == role_id,
        models.UserRole.org_code == current_user.org_code
    ).first()
    if not user_role:
        raise HTTPException(status_code=404, detail="User role assignment not found")
    
    db.delete(user_role)
    db.commit()
    return {"message": "Role removed from user"}