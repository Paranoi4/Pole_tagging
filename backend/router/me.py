from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import get_db
import schemas
from utils.auth import get_current_user

router = APIRouter(prefix="/me", tags=["User"])


@router.get("", response_model=schemas.UserOut)
def get_current_user_info(
    current_user = Depends(get_current_user)
):
    return schemas.UserOut.model_validate(current_user)