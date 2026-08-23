from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from config.database import get_db
import models.schemas as schemas
from utils.auth import get_current_user

router = APIRouter(prefix="/me", tags=["User"])


@router.get("", response_model=schemas.UserOut)
def get_current_user_info(
    current_user = Depends(get_current_user)
):
    return schemas.UserOut.model_validate(current_user)