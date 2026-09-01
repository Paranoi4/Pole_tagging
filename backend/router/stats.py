from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from config.database import get_db
import models.models as models
import models.schemas as schemas
from models.enums import BatchStatus, TagStatus
from utils.auth import get_current_user

router = APIRouter(prefix="/stats", tags=["Stats"])


# ============================================================
# PRINTERMAN DASHBOARD
# ============================================================

@router.get("/printerman", response_model=schemas.PrintermanStats)
def get_printerman_stats(
    du_id: int = Query(..., description="The DU whose pool to report on"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Every number on the printerman screen's stat row, in one call.

    One endpoint rather than one per tile: the four cards are a single unit on
    screen and are always shown together, so splitting them would mean the row
    could render half-populated while the second request was still open.

    The three counts are organization-wide for this DU. Only `current_batch` is
    scoped to the caller — see PrintermanStats.
    """
    du = db.query(models.DistributionUtility).filter(
        models.DistributionUtility.du_id == du_id,
        models.DistributionUtility.org_code == current_user.org_code,
    ).first()
    if not du:
        raise HTTPException(status_code=404, detail="DU not found")

    # One grouped query, not one COUNT per status. The pool holds 1,048,576 rows
    # per DU, so each extra full count is a scan of all of them.
    counts = dict(
        db.query(models.Tag.status, func.count(models.Tag.tag_id))
        .filter(
            models.Tag.du_id == du_id,
            models.Tag.org_code == current_user.org_code,
        )
        .group_by(models.Tag.status)
        .all()
    )

    # A batch stops being current once it is dispatched, not once it is printed,
    # so Printed stays in scope here exactly as it does in GET /batches/my-current.
    current_batch = (
        db.query(models.Batch)
        .filter(
            models.Batch.org_code == current_user.org_code,
            models.Batch.created_by == current_user.user_id,
            models.Batch.status.in_(
                [BatchStatus.PENDING.value, BatchStatus.PRINTED.value]
            ),
        )
        .order_by(models.Batch.created_at.desc(), models.Batch.batch_id.desc())
        .first()
    )

    return schemas.PrintermanStats(
        du_id=du_id,
        total_printed=counts.get(TagStatus.PRINTED.value, 0),
        available_in_pool=counts.get(TagStatus.AVAILABLE.value, 0),
        lost_printed=counts.get(TagStatus.LOST_PRINTED.value, 0),
        current_batch=current_batch,
    )
