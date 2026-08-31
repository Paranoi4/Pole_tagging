from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional

from config.database import get_db
import models.models as models
import models.schemas as schemas
from utils.auth import get_current_user, get_password_hash, require_role

router = APIRouter(
    prefix="/users",
    tags=["Users"],
    dependencies=[Depends(get_current_user)],
)


# ============================================
# CREATE USER
# ============================================
# Admin-only: this endpoint can assign roles at creation time, so it carries
# the same privilege-escalation risk as /user-roles.
@router.post("", response_model=schemas.UserOut, dependencies=[Depends(require_role("Admin"))])
def create_user(
    user: schemas.UserCreateAdmin,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    # Check if username exists
    if db.query(models.User).filter(models.User.username == user.username).first():
        raise HTTPException(status_code=400, detail="Username already exists")

    # Check if email exists
    if db.query(models.User).filter(models.User.email == user.email).first():
        raise HTTPException(status_code=400, detail="Email already exists")

    # Reject unknown roles before creating anything
    role_ids = list(dict.fromkeys(user.role_ids))
    if role_ids:
        found = db.query(models.Role).filter(models.Role.role_id.in_(role_ids)).count()
        if found != len(role_ids):
            raise HTTPException(status_code=404, detail="One or more roles not found")

    # Create user with hashed password
    db_user = models.User(
        first_name=user.first_name,
        last_name=user.last_name,
        middle_name=user.middle_name,
        suffix=user.suffix,
        email=user.email,
        contact=user.contact,
        username=user.username,
        password=get_password_hash(user.password),
        auth_provider="local",
        org_code=current_user.org_code,
    )
    db.add(db_user)
    db.flush()

    for role_id in role_ids:
        db.add(models.UserRole(
            user_id=db_user.user_id,
            role_id=role_id,
            org_code=current_user.org_code,
        ))

    db.commit()
    db.refresh(db_user)
    
    return schemas.UserOut.model_validate(db_user)

# ============================================
# GET ALL USERS (PAGINATED)
# ============================================
# Admin-only: this returns every user's email and contact info, not just
# the caller's own — not something a roleless or non-Admin account should
# be able to pull just by being logged in.
@router.get("", response_model=List[schemas.UserOut], dependencies=[Depends(require_role("Admin"))])
def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Admin sees ONLY users from their organization."""
    users = db.query(models.User).filter(
        models.User.org_code == current_user.org_code
    ).offset(skip).limit(limit).all()
    
    return [schemas.UserOut.model_validate(user) for user in users]


# ============================================
# GET USER BY ID
# ============================================
@router.get("/{user_id}", response_model=schemas.UserOut, dependencies=[Depends(require_role("Admin"))])
def get_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Admin can ONLY get users from their organization."""
    user = db.query(models.User).filter(
        models.User.user_id == user_id,
        models.User.org_code == current_user.org_code
    ).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return schemas.UserOut.model_validate(user)


# ============================================
# UPDATE USER
# ============================================
@router.put("/{user_id}", response_model=schemas.UserOut, dependencies=[Depends(require_role("Admin"))])
def update_user(
    user_id: int,
    patch: schemas.UserUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Admin can only update users within their own organization."""
    user = db.query(models.User).filter(
        models.User.user_id == user_id,
        models.User.org_code == current_user.org_code,
    ).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    data = patch.model_dump(exclude_unset=True)

    if data.get("username") and data["username"] != user.username:
        if db.query(models.User).filter(models.User.username == data["username"]).first():
            raise HTTPException(status_code=400, detail="Username already exists")

    if data.get("email") and data["email"] != user.email:
        if db.query(models.User).filter(models.User.email == data["email"]).first():
            raise HTTPException(status_code=400, detail="Email already exists")

    for field, value in data.items():
        if value is not None:
            setattr(user, field, value)

    db.commit()
    db.refresh(user)

    return schemas.UserOut.model_validate(user)


# ============================================
# DELETE USER
# ============================================
@router.delete("/{user_id}", dependencies=[Depends(require_role("Admin"))])
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Admin can only delete users within their own organization."""
    user = db.query(models.User).filter(
        models.User.user_id == user_id,
        models.User.org_code == current_user.org_code
    ).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    db.delete(user)
    db.commit()
    return {"message": "User deleted"}


# ============================================
# GET USER BY USERNAME
# ============================================
# users.py
@router.get("/username/{username}", response_model=schemas.UserOut)
def get_user_by_username(
    username: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Get a user by username. Only shows users from the same organization."""
    user = db.query(models.User).filter(
        models.User.username == username,
        models.User.org_code == current_user.org_code
    ).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return schemas.UserOut.model_validate(user)