from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime
from config.database import Base


class Role(Base):
    __tablename__ = "roles"

    role_id = Column(Integer, primary_key=True, index=True)
    role_name = Column(String(100), nullable=False, unique=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user_roles = relationship(
        "UserRole",
        back_populates="role",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


class DistributionUtility(Base):
    __tablename__ = "distribution_utilities"

    du_id = Column(Integer, primary_key=True, index=True)
    du_name = Column(String(255), nullable=False)
    du_code = Column(String(255), nullable=False, unique=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    created_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    
    creator = relationship("User", foreign_keys=[created_by])
    tags = relationship("Tag", back_populates="du", cascade="all, delete-orphan")
    batches = relationship("Batch", back_populates="du", cascade="all, delete-orphan")
    work_orders = relationship("WorkOrder", back_populates="du", cascade="all, delete-orphan")


class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, index=True)
    first_name = Column(String(255), nullable=False)
    last_name = Column(String(255), nullable=False)
    middle_name = Column(String(255), nullable=True)
    suffix = Column(String(255), nullable=True)
    email = Column(String(255), nullable=False, unique=True)
    contact = Column(String(255), nullable=True)
    username = Column(String(255), nullable=False, unique=True)
    password = Column(String(255), nullable=False)
    google_id = Column(String(255), nullable=True)
    auth_provider = Column(String(50), default="local")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    failed_login_attempts = Column(Integer, default=0, nullable=False)
    locked_until = Column(DateTime, nullable=True)

    user_roles = relationship(
        "UserRole",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

    @property
    def roles(self):
        return [user_role.role for user_role in self.user_roles if user_role.role]


class UserRole(Base):
    __tablename__ = "user_roles"

    user_role_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    role_id = Column(Integer, ForeignKey("roles.role_id", ondelete="CASCADE"), nullable=False)

    user = relationship("User", back_populates="user_roles")
    role = relationship("Role", back_populates="user_roles")


class Tag(Base):
    __tablename__ = "tags"

    tag_id = Column(Integer, primary_key=True, index=True)
    du_id = Column(Integer, ForeignKey("distribution_utilities.du_id", ondelete="CASCADE"), nullable=False)
    batch_id = Column(Integer, ForeignKey("batches.batch_id", ondelete="SET NULL"), nullable=True)
    tag_code = Column(String(20), nullable=False)
    pole_no = Column(String(255), nullable=False)
    status = Column(String(50), nullable=False, default="Available")
    remarks = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    updated_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)

    du = relationship("DistributionUtility", back_populates="tags")
    batch = relationship("Batch", back_populates="tags")
    creator = relationship("User", foreign_keys=[created_by])
    updater = relationship("User", foreign_keys=[updated_by])

    __table_args__ = (
        UniqueConstraint('du_id', 'tag_code', name='uq_tag_du_code'),
    )

    STATUS_AVAILABLE = "Available"
    STATUS_PRINTED = "Printed"
    STATUS_DISPATCHED = "Dispatched"
    STATUS_INSTALLED = "Installed"
    STATUS_LOST = "Lost"
    STATUS_DAMAGED = "Damaged"


# ============================================================
# BATCH (UPDATED - du_id REMOVED? NO! KEEP IT!)
# ============================================================

class Batch(Base):
    __tablename__ = "batches"

    batch_id = Column(Integer, primary_key=True, index=True)
    du_id = Column(Integer, ForeignKey("distribution_utilities.du_id", ondelete="CASCADE"), nullable=False)
    work_order_id = Column(Integer, ForeignKey("work_orders.work_order_id", ondelete="SET NULL"), nullable=True)
    batch_code = Column(String(50), nullable=False, unique=True)  # ← AUTO-GENERATED!
    quantity = Column(Integer, nullable=False, default=0)
    status = Column(String(50), nullable=False, default="Pending")
    assigned_to = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    created_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)

    du = relationship("DistributionUtility", back_populates="batches")
    work_order = relationship("WorkOrder", back_populates="batches")
    tags = relationship("Tag", back_populates="batch")
    assigned_crew = relationship("User", foreign_keys=[assigned_to])
    creator = relationship("User", foreign_keys=[created_by])

    STATUS_PENDING = "Pending"
    STATUS_PRINTED = "Printed"
    STATUS_DISPATCHED = "Dispatched"


# ============================================================
# WORK ORDER (NEW)
# ============================================================

class WorkOrder(Base):
    __tablename__ = "work_orders"

    work_order_id = Column(Integer, primary_key=True, index=True)
    du_id = Column(Integer, ForeignKey("distribution_utilities.du_id", ondelete="CASCADE"), nullable=False)
    work_order_name = Column(String(255), nullable=False)
    work_order_code = Column(String(50), nullable=False, unique=True)  # ← AUTO-GENERATED!
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    created_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)

    du = relationship("DistributionUtility", back_populates="work_orders")
    creator = relationship("User", foreign_keys=[created_by])
    batches = relationship("Batch", back_populates="work_order")