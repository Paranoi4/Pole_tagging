from pydantic import BaseModel, EmailStr, ConfigDict, Field
from typing import Optional
from datetime import datetime


# ===== ROLE =====
class RoleUpdate(BaseModel):
    role_name: Optional[str] = Field(default=None, min_length=1, max_length=100)

class RoleCreate(BaseModel):
    role_name: str = Field(min_length=1, max_length=100)

class RoleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    role_id: int
    role_name: str
    updated_at: Optional[datetime] = None


# ===== USER =====
class UserCreate(BaseModel):
    first_name: str = Field(min_length=1, max_length=255)
    last_name: str = Field(min_length=1, max_length=255)
    middle_name: Optional[str] = None
    suffix: Optional[str] = None
    email: EmailStr
    contact: Optional[str] = None
    username: str = Field(min_length=3, max_length=50)
    # bcrypt only reads the first 72 bytes, so anything longer is silently
    # truncated. Reject it up front rather than cutting it without telling anyone.
    password: str = Field(min_length=8, max_length=72)  # Plain password, will be hashed
    # auth_provider and google_id are set by the server, never by the client.


class UserCreateAdmin(UserCreate):
    """Used by POST /users, which requires a token.

    Public registration keeps using UserCreate, which has no role_ids, so
    nobody can grant themselves a role by signing up.
    """
    role_ids: list[int] = []


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
    model_config = ConfigDict(from_attributes=True)
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
    model_config = ConfigDict(from_attributes=True)
    user_role_id: int
    user_id: int
    role_id: int
    user: Optional[UserOut] = None
    role: Optional[RoleOut] = None


# ===== AUTH =====
class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str


class LoginResponse(TokenResponse):
    user: UserOut