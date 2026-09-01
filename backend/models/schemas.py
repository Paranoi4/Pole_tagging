from pydantic import BaseModel, EmailStr, ConfigDict, Field
from typing import Optional, List
from datetime import datetime

from models.enums import OrgCode, TagStatus

# ===== ROLE =====

class RoleCreate(BaseModel):
    role_name: str = Field(min_length=1, max_length=100)

class RoleUpdate(BaseModel):
    # No org_code: a role belongs to the organization that created it, and
    # moving one across organizations is never a legitimate edit.
    role_name: Optional[str] = Field(default=None, min_length=1, max_length=100)

class RoleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    role_id: int
    role_name: str
    updated_at: Optional[datetime] = None

class UserBase(BaseModel):
    first_name: str = Field(min_length=1, max_length=255)
    last_name: str = Field(min_length=1, max_length=255)
    middle_name: Optional[str] = None
    suffix: Optional[str] = None
    email: EmailStr
    contact: Optional[str] = None
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=8, max_length=72)


class UserCreate(UserBase):
    # Self-registration picks its own org. No role_ids here, so nobody can
    # grant themselves a role by signing up.
    org_code: OrgCode


class UserCreateAdmin(UserBase):
    # No org_code: the server takes it from the creating admin's token.
    role_ids: list[int] = []


class UserUpdate(BaseModel):
    # No org_code: users can't move themselves to another organization.
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
    org_code: str

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
    # No org_code: the server takes it from the creating admin's token.
    du_name: str = Field(min_length=1, max_length=255)
    du_code: str = Field(min_length=1, max_length=255)


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
    org_code: str
    # No nested `creator`. It embedded the full user — email, timestamps, roles
    # — inside every DU, and inside every response that nests a DU, for data no
    # client reads. `created_by` above is the id; fetch the person from
    # GET /users/{id} if a screen ever needs to show them.


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
    
    org_code: str
    # No nested `du` or `batches`. The batch list grows without bound as work
    # is done against the order, and both are already reachable through
    # GET /du/{id} and GET /batches?du_id=...

# ============================================================
# BATCH
# ============================================================

class BatchCreate(BaseModel):
    du_id: int
    work_order_id: int
    quantity: int = Field(ge=1, le=1000)
    # No crew or dispatcher here. A batch is created unassigned and only gets
    # either through PATCH /batches/{id}/assign, which validates the crew
    # against the caller's org and the batch's DU. Accepting one at creation
    # meant an arbitrary id was written with no validation at all.


class BatchUpdate(BaseModel):
    status: Optional[str] = None


class NextBatchCode(BaseModel):
    next_batch_code: str


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
    # The hand-over record: which crew has it, who released it, and when. All
    # three are null until the batch is dispatched, and all three are cleared
    # together if it is returned.
    #
    # Flat ids only — the dispatcher already holds the crew list it chose from,
    # so nesting the crew object here would repeat the same label and city on
    # every batch in a page.
    assigned_crew_id: Optional[int] = None
    dispatched_by: Optional[int] = None
    dispatched_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    created_by: Optional[int] = None

    du: Optional[DUOut] = None
    work_order: Optional[WorkOrderSummary] = None
    org_code: str
    # No `tags` list. A batch holds up to 1000 of them and each TagOut nests its
    # own du and batch, so including them made one batch ~275 KB and a page of
    # GET /batches ~27 MB. Tags are fetched through GET /batches/{id}/tags.

# ============================================================
# TAG
# ============================================================

class TagCreate(BaseModel):
    du_id: int
    tag_code: str = Field(min_length=4, max_length=20)
    pole_no: str = Field(min_length=1, max_length=255)
    status: Optional[str] = Field(default=TagStatus.AVAILABLE.value)
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
    # Sent flat alongside the nested `batch` object, the same way du_id sits
    # beside `du` — a client that only needs the id should not have to reach
    # into the nested object for it.
    batch_id: Optional[int] = None
    tag_code: str
    pole_no: str
    status: str
    remarks: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    created_by: Optional[int] = None
    updated_by: Optional[int] = None
    
    org_code: str
    # No nested `du` or `batch`. Both are identical across every tag in a
    # response, so 500 tags carried 500 copies of the same two objects and
    # doubled the payload of GET /batches/{id}/tags. The flat du_id and
    # batch_id above identify them; fetch the objects themselves from
    # GET /du/{id} and GET /batches/{id} when they are actually needed.

    @property
    def full_tag(self) -> str:
        return self.tag_code

class CityCreate(BaseModel):
    city_name: str = Field(min_length=1, max_length=255)
    du_id: int


class CityOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    city_id: int
    city_name: str
    du_id: int
    org_code: str
    created_by: Optional[int] = None

class CityUpdate(BaseModel):
    city_name: Optional[str] = Field(default=None, min_length=1, max_length=255)
    du_id: Optional[int] = None


class CrewCreate(BaseModel):
    crew_label: str = Field(min_length=1, max_length=255)
    city_id: Optional[int] = None


class CrewOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    crew_id: int
    crew_label: str
    city_id: Optional[int] = None
    city: Optional[CityOut] = None
    org_code: str
    created_by: Optional[int] = None

class CrewUpdate(BaseModel):
    crew_label: Optional[str] = Field(default=None, min_length=1, max_length=255)
    city_id: Optional[int] = None

# ============================================================
# AUDIT LOG
# ============================================================

class AuditLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    audit_id: int
    entity_type: str
    entity_id: int
    # Null only on rows written before entity_code existed whose entity has
    # since been deleted; every new row carries it.
    entity_code: Optional[str] = None
    from_status: Optional[str] = None
    to_status: Optional[str] = None
    remarks: Optional[str] = None
    created_at: datetime
    performed_by: Optional[int] = None
    # Resolved from the joined user so the trail reads as names rather than ids.
    # Null if that account has since been deleted (performed_by is SET NULL).
    performed_by_name: Optional[str] = None


class AuditLogPage(BaseModel):
    """A page of the trail plus the total behind it.

    The count comes back with the page because the screen's header states how
    many events exist; asking for it separately would be a second round trip for
    a number the same request could have carried.
    """

    total: int
    items: List[AuditLogOut]
