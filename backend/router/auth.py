from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from sqlalchemy import or_
from datetime import timedelta, datetime
from urllib.parse import urlencode
import requests

from google.oauth2 import id_token
from google.auth.transport import requests as google_requests

from config.database import get_db
import models.models as models
import models.schemas as schemas
from config.config import GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REDIRECT_URI, FRONTEND_URL  
from utils.auth import verify_password, create_access_token, get_password_hash, ACCESS_TOKEN_EXPIRE_SECONDS

router = APIRouter(prefix="/auth", tags=["Authentication"])

# Login lockout: 5 wrong passwords in a row locks the account for 5 minutes.
# The counter resets on its own once the lockout passes, even without a
# successful login in between — see the `locked_until` check below.
MAX_FAILED_LOGIN_ATTEMPTS = 5
LOCKOUT_DURATION = timedelta(minutes=5)


# ===== LOGIN =====
@router.post("/login", response_model=schemas.LoginResponse)
def login(
    request: schemas.LoginRequest,
    db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(
        or_(
            models.User.username == request.username,
            models.User.email == request.username,
        )
    ).first()
    if not user:
        raise HTTPException(status_code=401, detail="Invalid username or password")

    # A lock still in effect blocks the attempt outright — checked before the
    # password is even verified, so a locked account can't be probed further.
    now = datetime.utcnow()
    if user.locked_until and user.locked_until > now:
        remaining_seconds = int((user.locked_until - now).total_seconds())
        remaining_minutes = max(1, (remaining_seconds + 59) // 60)
        raise HTTPException(
            status_code=429,
            detail=(
                f"Too many failed login attempts. Try again in "
                f"{remaining_minutes} minute(s)."
            ),
        )

    # The lock has expired (or never existed) but a stale counter is still
    # sitting here from before — clear it now so a fresh 5-attempt window
    # starts, without requiring a successful login first.
    if user.locked_until and user.locked_until <= now:
        user.failed_login_attempts = 0
        user.locked_until = None

    # Google accounts hold a placeholder password hash, so they must never be
    # allowed through the password login path.
    if (user.auth_provider or "local") != "local":
        raise HTTPException(
            status_code=400,
            detail="This account uses Google sign-in. Please continue with Google.",
        )

    if not verify_password(request.password, user.password):
        user.failed_login_attempts = (user.failed_login_attempts or 0) + 1

        if user.failed_login_attempts >= MAX_FAILED_LOGIN_ATTEMPTS:
            user.locked_until = now + LOCKOUT_DURATION
            db.commit()
            raise HTTPException(
                status_code=429,
                detail=(
                    f"Too many failed login attempts. Try again in "
                    f"{int(LOCKOUT_DURATION.total_seconds() // 60)} minute(s)."
                ),
            )

        db.commit()
        raise HTTPException(status_code=401, detail="Invalid username or password")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="User account is inactive")

    # Successful login clears the counter, same as a naturally expired lock.
    user.failed_login_attempts = 0
    user.locked_until = None
    db.commit()

    access_token_expires = timedelta(seconds=ACCESS_TOKEN_EXPIRE_SECONDS)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": user,
    }


@router.get("/google/login")
def google_login():
    if not GOOGLE_CLIENT_ID:
        raise HTTPException(
            status_code=500,
            detail="Google login is not configured. Add GOOGLE_CLIENT_ID to backend/.env",
        )

    params = {
        "client_id": GOOGLE_CLIENT_ID,
        "redirect_uri": GOOGLE_REDIRECT_URI,
        "response_type": "code",
        "scope": "openid email profile",
        "access_type": "offline",
        "prompt": "consent",
    }
    google_auth_url = "https://accounts.google.com/o/oauth2/v2/auth?" + urlencode(params)
    return RedirectResponse(google_auth_url)


@router.get("/google/callback")
def google_callback(code: str, db: Session = Depends(get_db)):
    if not GOOGLE_CLIENT_ID or not GOOGLE_CLIENT_SECRET:
        raise HTTPException(
            status_code=500,
            detail="Google OAuth credentials are missing. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET.",
        )

    token_response = requests.post(
        "https://oauth2.googleapis.com/token",
        data={
            "code": code,
            "client_id": GOOGLE_CLIENT_ID,
            "client_secret": GOOGLE_CLIENT_SECRET,
            "redirect_uri": GOOGLE_REDIRECT_URI,
            "grant_type": "authorization_code",
        },
        timeout=20,
    )

    if token_response.status_code != 200:
        raise HTTPException(status_code=400, detail="Google token exchange failed")

    token_data = token_response.json()
    id_token_value = token_data.get("id_token")
    if not id_token_value:
        raise HTTPException(status_code=400, detail="Google did not return an ID token")

    try:
        google_user = id_token.verify_oauth2_token(
            id_token_value,
            google_requests.Request(),
            GOOGLE_CLIENT_ID,
        )
    except Exception as exc:
        raise HTTPException(status_code=401, detail=f"Invalid Google token: {exc}") from exc

    email = google_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Google account email is required")

    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        user = models.User(
            first_name=(google_user.get("given_name") or "Google").strip() or "Google",
            last_name=(google_user.get("family_name") or "User").strip() or "User",
            email=email,
            username=email.split("@")[0],
            password=get_password_hash("google-oauth-user"),
            auth_provider="google",
            google_id=google_user.get("sub"),
            org_code="NP", 
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    if not user.is_active:
        raise HTTPException(status_code=403, detail="User account is inactive")

    access_token_expires = timedelta(seconds=ACCESS_TOKEN_EXPIRE_SECONDS)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )

    redirect_url = (
        f"{FRONTEND_URL}/login?google_auth=true&token="
        f"{access_token}&username={user.username}"
    )
    return RedirectResponse(redirect_url)

# ===== REGISTER =====
# router/auth.py

# ===== REGISTER =====
@router.post("/register", response_model=schemas.UserOut)
def register(
    user: schemas.UserCreate,
    db: Session = Depends(get_db)
):
    if db.query(models.User).filter(models.User.username == user.username).first():
        raise HTTPException(status_code=400, detail="Username already exists")

    if db.query(models.User).filter(models.User.email == user.email).first():
        raise HTTPException(status_code=400, detail="Email already exists")

    # No role is assigned here. Admins for NP/BP/MP already exist — new
    # self-registrations land with no roles and see NoRolesScreen until an
    # existing Admin assigns one via /user-roles.
    db_user = models.User(
        first_name=user.first_name,
        last_name=user.last_name,
        middle_name=user.middle_name,
        suffix=user.suffix,
        email=user.email,
        contact=user.contact,
        username=user.username,
        password=get_password_hash(user.password),
        auth_provider="local",
        org_code=user.org_code,
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)

    return schemas.UserOut.model_validate(db_user)