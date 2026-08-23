from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from config.database import get_db
import models.models as models
import models.schemas as schemas
from utils.auth import get_current_user

router = APIRouter(
    prefix="/user-roles",
    tags=["User Roles"],
    dependencies=[Depends(get_current_user)],
)


# ===== ASSIGN ROLE TO USER =====
@router.post("", response_model=schemas.UserRoleOut)
def assign_role_to_user(
    payload: schemas.UserRoleCreate,
    db: Session = Depends(get_db)
):
    # Check if user exists
    if not db.get(models.User, payload.user_id):
        raise HTTPException(status_code=404, detail="User not found")
    
    # Check if role exists
    if not db.get(models.Role, payload.role_id):
        raise HTTPException(status_code=404, detail="Role not found")
    
    # Check if already assigned
    existing = db.query(models.UserRole).filter(
        models.UserRole.user_id == payload.user_id,
        models.UserRole.role_id == payload.role_id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Role already assigned to user")
    
    db_user_role = models.UserRole(**payload.model_dump())
    db.add(db_user_role)
    db.commit()
    db.refresh(db_user_role)
    
    return schemas.UserRoleOut.model_validate(db_user_role)


# A user's roles are already returned by GET /users/{id} and by the login
# response, so this router only covers assigning and removing.


# ===== REMOVE ROLE FROM USER BY USER AND ROLE ID =====
@router.delete("/user/{user_id}/role/{role_id}")
def remove_role_by_ids(
    user_id: int,
    role_id: int,
    db: Session = Depends(get_db)
):
    user_role = db.query(models.UserRole).filter(
        models.UserRole.user_id == user_id,
        models.UserRole.role_id == role_id
    ).first()
    if not user_role:
        raise HTTPException(status_code=404, detail="User role assignment not found")
    
    db.delete(user_role)
    db.commit()
    return {"message": "Role removed from user"}