from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


# ===== ROLE =====
class RoleUpdate(BaseModel):
    role_name: Optional[str] = None

class RoleCreate(BaseModel):
    role_name: str

class RoleOut(BaseModel):
    role_id: int
    role_name: str
    updated_at: Optional[datetime] = None


# ===== USER =====
class UserCreate(BaseModel):
    first_name: str
    last_name: str
    middle_name: Optional[str] = None
    suffix: Optional[str] = None
    email: EmailStr
    contact: Optional[str] = None
    username: str
    password: str  # Plain password, will be hashed
    auth_provider: Optional[str] = "local"
    google_id: Optional[str] = None


class UserUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    middle_name: Optional[str] = None
    suffix: Optional[str] = None
    email: Optional[EmailStr] = None
    contact: Optional[str] = None
    username: Optional[str] = None
    is_active: Optional[bool] = None


class UserOut(BaseModel):
    user_id: int
    first_name: str
    last_name: str
    middle_name: Optional[str] = None
    suffix: Optional[str] = None
    email: str
    contact: Optional[str] = None
    username: str
    is_active: bool
    auth_provider: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    roles: list[RoleOut] = []


# ===== USER ROLE =====
class UserRoleCreate(BaseModel):
    user_id: int
    role_id: int


class UserRoleOut(BaseModel):
    user_role_id: int
    user_id: int
    role_id: int
    user: Optional[UserOut] = None
    role: Optional[RoleOut] = None