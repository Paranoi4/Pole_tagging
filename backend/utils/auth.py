from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from config.config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_SECONDS
from config.database import get_db
import models.models as models
from models.enums import RoleName

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

security = HTTPBearer()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(seconds=ACCESS_TOKEN_EXPIRE_SECONDS)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security), db: Session = Depends(get_db)):
    token = credentials.credentials
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = db.query(models.User).filter(models.User.username == username).first()
    if user is None:
        raise credentials_exception

    # Checked on every request, not just at login, so deactivating an account
    # takes effect immediately instead of when the token happens to expire.
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive",
        )

    return user


def require_role(*allowed_roles: "RoleName | str"):
    """Dependency factory: restricts a route to users holding at least one of
    the given role names. A user can hold multiple roles (e.g. Printerman AND
    Dispatcher) — this only requires overlap, not an exact match.

    Accepts RoleName members or plain strings; both are compared as their
    string value against `roles.role_name`.

    Usage:
        @router.post("", dependencies=[Depends(require_role(RoleName.ADMIN))])
    or, if you need the resolved user in the route body:
        def my_route(current_user = Depends(require_role(RoleName.ADMIN))):
    """
    allowed = {str(role) for role in allowed_roles}

    def role_checker(current_user: models.User = Depends(get_current_user)):
        user_role_names = {r.role_name for r in current_user.roles}
        if user_role_names.isdisjoint(allowed):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires one of these roles: {', '.join(sorted(allowed))}",
            )
        return current_user
    return role_checker