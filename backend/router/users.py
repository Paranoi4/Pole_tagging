from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from passlib.context import CryptContext

from database import get_db
import models
import schemas

router = APIRouter(prefix="/users", tags=["Users"])

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)


# ============================================
# CREATE USER
# ============================================
@router.post("", response_model=schemas.UserOut)
def create_user(
    user: schemas.UserCreate,
    db: Session = Depends(get_db)
):
    # Check if username exists
    if db.query(models.User).filter(models.User.username == user.username).first():
        raise HTTPException(status_code=400, detail="Username already exists")
    
    # Check if email exists
    if db.query(models.User).filter(models.User.email == user.email).first():
        raise HTTPException(status_code=400, detail="Email already exists")
    
    # Create user with hashed password
    db_user = models.User(
        first_name=user.first_name,
        last_name=user.last_name,
        middle_name=user.middle_name,
        suffix=user.suffix,
        email=user.email,
        contact=user.contact,
        username=user.username,
        password=hash_password(user.password),
        auth_provider=user.auth_provider or "local",
        google_id=user.google_id
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    # ✅ ONE LINE instead of 14!
    return schemas.UserOut.model_validate(db_user)


# ============================================
# GET ALL USERS (PAGINATED)
# ============================================
@router.get("", response_model=List[schemas.UserOut])
def list_users(
    skip: int = Query(0, description="Number of users to skip"),
    limit: int = Query(10, description="Number of users to return"),
    db: Session = Depends(get_db)
):
    users = db.query(models.User).offset(skip).limit(limit).all()
    
    # ✅ Convert each user using model_validate
    return [schemas.UserOut.model_validate(user) for user in users]


# ============================================
# GET USER BY ID
# ============================================
@router.get("/{user_id}", response_model=schemas.UserOut)
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.get(models.User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # ✅ ONE LINE instead of 14!
    return schemas.UserOut.model_validate(user)


# ============================================
# UPDATE USER
# ============================================
@router.put("/{user_id}", response_model=schemas.UserOut)
def update_user(
    user_id: int,
    patch: schemas.UserUpdate,
    db: Session = Depends(get_db)
):
    user = db.get(models.User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    for field, value in patch.model_dump(exclude_unset=True).items():
        if field == "password" and value:
            setattr(user, field, hash_password(value))
        elif value is not None:
            setattr(user, field, value)
    
    db.commit()
    db.refresh(user)
    
    # ✅ ONE LINE instead of 14!
    return schemas.UserOut.model_validate(user)


# ============================================
# DELETE USER
# ============================================
@router.delete("/{user_id}")
def delete_user(user_id: int, db: Session = Depends(get_db)):
    user = db.get(models.User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    db.delete(user)
    db.commit()
    return {"message": "User deleted"}


# ============================================
# GET USER BY USERNAME
# ============================================
@router.get("/username/{username}", response_model=schemas.UserOut)
def get_user_by_username(username: str, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # ✅ ONE LINE instead of 14!
    return schemas.UserOut.model_validate(user)