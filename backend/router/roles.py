from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List

from config.database import get_db
import models.models as models
import models.schemas as schemas
from utils.auth import get_current_user

router = APIRouter(
    prefix="/roles",
    tags=["Roles"],
    dependencies=[Depends(get_current_user)],
)


# ===== CREATE ROLE =====
@router.post("", response_model=schemas.RoleOut)
def create_role(role: schemas.RoleCreate, db: Session = Depends(get_db)):
    if db.query(models.Role).filter(models.Role.role_name == role.role_name).first():
        raise HTTPException(status_code=400, detail="Role already exists")
    
    db_role = models.Role(**role.model_dump())
    db.add(db_role)
    db.commit()
    db.refresh(db_role)
    return db_role


# ===== GET ALL ROLES =====
@router.get("", response_model=List[schemas.RoleOut])
def list_roles(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100),
    db: Session = Depends(get_db)
):
    return db.query(models.Role).offset(skip).limit(limit).all()


# ===== GET ROLE BY ID =====
@router.get("/{role_id}", response_model=schemas.RoleOut)
def get_role(role_id: int, db: Session = Depends(get_db)):
    role = db.get(models.Role, role_id)
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    return role


# ===== UPDATE ROLE =====
@router.put("/{role_id}", response_model=schemas.RoleOut)
def update_role(
    role_id: int,
    patch: schemas.RoleUpdate,
    db: Session = Depends(get_db)
):
    role = db.get(models.Role, role_id)
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    
    data = patch.model_dump(exclude_unset=True)

    # Same uniqueness check create_role does, so a clash returns 400 rather
    # than letting the database raise and surface as a 500.
    if data.get("role_name") and data["role_name"] != role.role_name:
        if db.query(models.Role).filter(models.Role.role_name == data["role_name"]).first():
            raise HTTPException(status_code=400, detail="Role already exists")

    for field, value in data.items():
        if value is not None:
            setattr(role, field, value)

    db.commit()
    db.refresh(role)
    return role


# ===== DELETE ROLE =====
@router.delete("/{role_id}")
def delete_role(role_id: int, db: Session = Depends(get_db)):
    role = db.get(models.Role, role_id)
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    
    db.delete(role)
    db.commit()
    return {"message": "Role deleted"}