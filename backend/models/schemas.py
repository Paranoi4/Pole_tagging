from pydantic import BaseModel, EmailStr, ConfigDict, Field
from typing import Literal, Optional, List
from datetime import datetime
# The only orgs this deployment serves. Centralized here so every schema
# stays in sync — add a new org by editing this one line
OrgCode = Literal["NP", "BP", "MP"]

# ===== ROLE =====
class RoleUpdate(BaseModel):
    role_name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    org_code: str  # ✅ ADD THIS

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
    password: str = Field(min_length=8, max_length=72)
    org_code: OrgCode


class UserCreateAdmin(UserCreate):
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
    org_code: Optional[str] = None  # ✅ ADD THIS

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
    org_code: str  # ✅ ADD THIS

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


# ============================================================
# DISTRIBUTION UTILITY
# ============================================================

class DUCreate(BaseModel):
    du_name: str = Field(min_length=1, max_length=255)
    du_code: str = Field(min_length=1, max_length=255)
    org_code: str = Field(min_length=2, max_length=10)  # ✅ MANUAL ORG CODE INPUT


class DUUpdate(BaseModel):
    du_name: Optional[str] = Field(default=None, min_length=1, max_length=255)
    du_code: Optional[str] = Field(default=None, min_length=1, max_length=255)
    is_active: Optional[bool] = None


class DUOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    du_id: int
    du_name: str
    du_code: str
    is_active: bool
    created_at: Optional[datetime] = None
    created_by: Optional[int] = None
    creator: Optional[UserOut] = None
    org_code: str  # ✅ ADD THIS


class DUWithStats(DUOut):
    tags_count: int = 0
    available_count: int = 0
    printed_count: int = 0
    dispatched_count: int = 0


# ============================================================
# WORK ORDER
# ============================================================

class WorkOrderCreate(BaseModel):
    du_id: int
    work_order_name: str = Field(min_length=1, max_length=255)
    description: Optional[str] = None


class WorkOrderUpdate(BaseModel):
    work_order_name: Optional[str] = Field(default=None, min_length=1, max_length=255)
    description: Optional[str] = None


class WorkOrderSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    work_order_id: int
    du_id: int
    work_order_name: str
    work_order_code: str


class WorkOrderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    work_order_id: int
    du_id: int
    work_order_name: str
    work_order_code: str
    description: Optional[str] = None
    created_at: Optional[datetime] = None
    created_by: Optional[int] = None
    
    du: Optional[DUOut] = None
    batches: List["BatchSummary"] = []
    org_code: str  # ✅ ADD THIS

# ============================================================
# BATCH
# ============================================================

class BatchCreate(BaseModel):
    du_id: int
    work_order_id: int
    quantity: int = Field(ge=1, le=1000)
    assigned_to: Optional[int] = None


class BatchUpdate(BaseModel):
    status: Optional[str] = None
    assigned_to: Optional[int] = None


class BatchSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    batch_id: int
    du_id: int
    work_order_id: Optional[int] = None
    batch_code: str
    quantity: int
    status: str


class BatchOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    batch_id: int
    du_id: int
    work_order_id: Optional[int] = None
    batch_code: str
    quantity: int
    status: str
    assigned_to: Optional[int] = None
    created_at: Optional[datetime] = None
    created_by: Optional[int] = None
    
    du: Optional[DUOut] = None
    work_order: Optional[WorkOrderSummary] = None
    tags: List["TagOut"] = []
    assigned_crew: Optional[UserOut] = None
    org_code: str  # ✅ ADD THIS

# ============================================================
# TAG
# ============================================================

class TagCreate(BaseModel):
    du_id: int
    tag_code: str = Field(min_length=4, max_length=20)
    pole_no: str = Field(min_length=1, max_length=255)
    status: Optional[str] = Field(default="Available")
    remarks: Optional[str] = None


class TagUpdate(BaseModel):
    tag_code: Optional[str] = Field(default=None, min_length=4, max_length=20)
    pole_no: Optional[str] = Field(default=None, min_length=1, max_length=255)
    status: Optional[str] = None
    remarks: Optional[str] = None


class TagOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    tag_id: int
    du_id: int
    tag_code: str
    pole_no: str
    status: str
    remarks: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    created_by: Optional[int] = None
    updated_by: Optional[int] = None
    
    du: Optional[DUOut] = None
    batch: Optional[BatchSummary] = None
    org_code: str  # ✅ ADD THIS
    @property
    def full_tag(self) -> str:
        return self.tag_code