from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from config.database import Base


class Role(Base):
    __tablename__ = "roles"

    role_id = Column(Integer, primary_key=True, index=True)
    role_name = Column(String(100), nullable=False, unique=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationship
    user_roles = relationship(
        "UserRole",
        back_populates="role",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


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
    password = Column(String(255), nullable=False)  # Store hashed passwords
    google_id = Column(String(255), nullable=True)
    auth_provider = Column(String(50), default="local")  # local, google, etc.
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Login lockout: after 5 wrong passwords in a row, locked_until is set to
    # 5 minutes out and login is refused until that passes. failed_login_attempts
    # resets to 0 either on a successful login or once locked_until has passed
    # (whichever comes first) — see login() in router/auth.py.
    failed_login_attempts = Column(Integer, default=0, nullable=False)
    locked_until = Column(DateTime, nullable=True)

    # Relationship
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

    # Relationships
    user = relationship("User", back_populates="user_roles")
    role = relationship("Role", back_populates="user_roles")