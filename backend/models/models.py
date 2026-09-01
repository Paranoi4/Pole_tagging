from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, UniqueConstraint, Index
from sqlalchemy.orm import relationship
from datetime import datetime
from config.database import Base


class Role(Base):
    __tablename__ = "roles"

    role_id = Column(Integer, primary_key=True, index=True)
    role_name = Column(String(100), nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    org_code = Column(String(10), nullable=False)

    user_roles = relationship(
        "UserRole",
        back_populates="role",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    __table_args__ = (
        UniqueConstraint('role_name', 'org_code', name='uq_role_name_org'),
    )

class DistributionUtility(Base):
    __tablename__ = "distribution_utilities"

    du_id = Column(Integer, primary_key=True, index=True)
    du_name = Column(String(255), nullable=False)
    du_code = Column(String(255), nullable=False, unique=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    created_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    org_code = Column(String(10), nullable=False)
    
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
    crew_id = Column(Integer, ForeignKey("crews.crew_id", ondelete="SET NULL"), nullable=True)
    crew = relationship("Crew", back_populates="members", foreign_keys=[crew_id])
    failed_login_attempts = Column(Integer, default=0, nullable=False)
    locked_until = Column(DateTime, nullable=True)
    org_code = Column(String(10), nullable=False)
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
    org_code = Column(String(10), nullable=False)
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
    org_code = Column(String(10), nullable=False)
    du = relationship("DistributionUtility", back_populates="tags")
    batch = relationship("Batch", back_populates="tags")
    creator = relationship("User", foreign_keys=[created_by])
    updater = relationship("User", foreign_keys=[updated_by])

    __table_args__ = (
        UniqueConstraint('du_id', 'tag_code', name='uq_tag_du_code'),
        # "The tags in this batch" is the most frequent query in the app — the
        # printerman's current batch, the print sheet's refresh, every batch the
        # dispatcher opens. Without this the pool's three million rows were
        # scanned in full to return the twenty-four belonging to one batch,
        # about 725ms per call; with it, ~0.05ms.
        Index('ix_tags_batch_id', 'batch_id'),
    )

    STATUS_AVAILABLE = "Available"
    STATUS_PRINTED = "Printed"
    STATUS_DISPATCHED = "Dispatched"
    STATUS_INSTALLED = "Installed"
    STATUS_LOST_PRINTED = "Lost Printed"
    STATUS_DO_NOT_USE = "Do Not Use"
    STATUS_DAMAGED = "Damaged"


# ============================================================
# BATCH (UPDATED - du_id REMOVED? NO! KEEP IT!)
# ============================================================

class Batch(Base):
    __tablename__ = "batches"

    batch_id = Column(Integer, primary_key=True, index=True)
    du_id = Column(Integer, ForeignKey("distribution_utilities.du_id", ondelete="CASCADE"), nullable=False)
    work_order_id = Column(Integer, ForeignKey("work_orders.work_order_id", ondelete="SET NULL"), nullable=True)
    # Server-generated (BT-{du_code}-{year}-{seq}), never client-supplied.
    batch_code = Column(String(50), nullable=False, unique=True)
    quantity = Column(Integer, nullable=False, default=0)
    status = Column(String(50), nullable=False, default="Pending")
    # The staff member who released the batch — the other half of the hand-over
    # record. Stamped from the token holder, never accepted from the client, the
    # same way created_by is. Was called `assigned_to` back when a batch was
    # handed to a user rather than to a crew.
    dispatched_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    # Who the batch was handed to in the field. A crew, not a user: crews are
    # labelled by their lead and tied to a city, which is what the dispatcher
    # picks from.
    assigned_crew_id = Column(Integer, ForeignKey("crews.crew_id", ondelete="SET NULL"), nullable=True)
    # When the batch was handed to that crew. Null until it goes out, and never
    # rewritten afterwards: `status` only says a batch *is* dispatched, and the
    # tags' own updated_at is overwritten by the next field scan, so without
    # this the moment of hand-over is not recorded anywhere.
    dispatched_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    created_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    org_code = Column(String(10), nullable=False)
    du = relationship("DistributionUtility", back_populates="batches")
    work_order = relationship("WorkOrder", back_populates="batches")
    tags = relationship("Tag", back_populates="batch")
    crew = relationship("Crew", foreign_keys=[assigned_crew_id])
    dispatcher = relationship("User", foreign_keys=[dispatched_by])
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
    # Server-generated, never client-supplied.
    work_order_code = Column(String(50), nullable=False, unique=True)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    created_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    org_code = Column(String(10), nullable=False)
    du = relationship("DistributionUtility", back_populates="work_orders")
    creator = relationship("User", foreign_keys=[created_by])
    batches = relationship("Batch", back_populates="work_order")

class City(Base):
    __tablename__ = "cities"

    city_id = Column(Integer, primary_key=True, index=True)
    du_id = Column(Integer, ForeignKey("distribution_utilities.du_id", ondelete="CASCADE"), nullable=False)
    org_code = Column(String(10), nullable=False)
    city_name = Column(String(255), nullable=False)
    created_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)

    du = relationship("DistributionUtility")
    creator = relationship("User", foreign_keys=[created_by])


class Crew(Base):
    __tablename__ = "crews"

    crew_id = Column(Integer, primary_key=True, index=True)
    city_id = Column(Integer, ForeignKey("cities.city_id", ondelete="SET NULL"), nullable=True)
    crew_label = Column(String(255), nullable=False)
    org_code = Column(String(10), nullable=False)
    created_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)

    city = relationship("City")
    creator = relationship("User", foreign_keys=[created_by])
    members = relationship("User", back_populates="crew", foreign_keys="User.crew_id")

class AuditLog(Base):
    """Append-only record of every status change to a tag or a batch.

    Exists because the tables it watches only ever hold *current* state: `status`
    is overwritten on each change and `remarks` with it, so "what happened to
    this tag, when, and who did it" was unanswerable. Each change appends a row
    here instead of replacing what came before.

    Written inside the same transaction as the change it describes, so the two
    cannot disagree — if the change rolls back, so does its log entry.
    """

    __tablename__ = "audit_log"

    audit_id = Column(Integer, primary_key=True, index=True)
    performed_by = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)

    # Deliberately not a foreign key. It holds a tags.tag_id or a
    # batches.batch_id depending on entity_type, and one column cannot reference
    # two tables. That also means history outlives what it describes: deleting a
    # batch leaves its audit trail intact, which is the whole point of keeping
    # one. Pair it with entity_type — an id alone is ambiguous.
    entity_type = Column(String(20), nullable=False)
    entity_id = Column(Integer, nullable=False)

    # The human-readable code as it stood at the time — "BT-N-2026-0048" or
    # "N31YF". Copied rather than looked up, which is deliberate for a log: the
    # id alone cannot be resolved once the row it points at is gone, and a
    # deleted batch is exactly the case an audit trail exists to explain. It also
    # spares every read a polymorphic join across tags and batches.
    entity_code = Column(String(50), nullable=True)

    org_code = Column(String(10), nullable=False)

    # Null on a creation entry, where there was no previous state.
    from_status = Column(String(50), nullable=True)
    to_status = Column(String(50), nullable=True)

    # The reason given for this particular change, kept forever. The tag's own
    # `remarks` column holds only the latest one; this is where the history of
    # them lives.
    remarks = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    performer = relationship("User", foreign_keys=[performed_by])

    __table_args__ = (
        # "Show me this tag's history" is the only read this table has, and it
        # always arrives as an (entity_type, entity_id) pair.
        Index("ix_audit_log_entity", "entity_type", "entity_id"),
    )
