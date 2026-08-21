from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from database import get_db
import models
import schemas

router = APIRouter(prefix="/user-roles", tags=["User Roles"])


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
    return db_user_role


# ===== GET ALL USER ROLES =====
@router.get("", response_model=List[schemas.UserRoleOut])
def list_user_roles(
    skip: int = 0,
    limit: int = 10,
    db: Session = Depends(get_db)
):
    return db.query(models.UserRole).offset(skip).limit(limit).all()


# ===== GET USER ROLES BY USER ID =====
@router.get("/user/{user_id}", response_model=List[schemas.UserRoleOut])
def get_user_roles_by_user(user_id: int, db: Session = Depends(get_db)):
    if not db.get(models.User, user_id):
        raise HTTPException(status_code=404, detail="User not found")
    
    return db.query(models.UserRole).filter(models.UserRole.user_id == user_id).all()


# ===== REMOVE ROLE FROM USER =====
@router.delete("/{user_role_id}")
def remove_role_from_user(user_role_id: int, db: Session = Depends(get_db)):
    user_role = db.get(models.UserRole, user_role_id)
    if not user_role:
        raise HTTPException(status_code=404, detail="User role assignment not found")
    
    db.delete(user_role)
    db.commit()
    return {"message": "Role removed from user"}


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