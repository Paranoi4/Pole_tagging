from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload
from typing import Optional

from config.database import get_db
import models.models as models
import models.schemas as schemas
from models.enums import RoleName
from utils.auth import get_current_user, require_role

router = APIRouter(prefix="/audit-log", tags=["Audit log"])

MAX_PAGE = 200


def _display_name(user: Optional[models.User]) -> Optional[str]:
    """"R. Alunan" from the stored first and last name, falling back to the
    username when a name is missing."""
    if user is None:
        return None
    first = (user.first_name or "").strip()
    last = (user.last_name or "").strip()
    if first and last:
        return f"{first[0]}. {last}"
    return last or first or user.username


@router.get(
    "",
    response_model=schemas.AuditLogPage,
    dependencies=[Depends(require_role(RoleName.ADMIN))],
)
def list_audit_log(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=MAX_PAGE),
    search: Optional[str] = Query(
        None,
        min_length=1,
        max_length=100,
        description="Matches a tag or batch code, a remark, or a person's name",
    ),
    entity_type: Optional[str] = Query(
        None,
        pattern="^(tag|batch)$",
        description="Narrow to tag activity or batch activity",
    ),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """The organization's audit trail, newest first.

    Admin only, and scoped to the caller's own `org_code` — the trail names who
    did what to which codes, so one organization seeing another's would be worse
    than leaking the underlying rows.

    Paginated because this is the fastest-growing table in the schema: printing
    one batch writes a row per tag, so it outgrows everything else. `total` comes
    back with the page for the screen's header.
    """
    query = db.query(models.AuditLog).filter(
        models.AuditLog.org_code == current_user.org_code
    )

    if entity_type:
        query = query.filter(models.AuditLog.entity_type == entity_type)

    if search:
        term = f"%{search.strip()}%"
        # The person is matched through a join rather than a stored name, so a
        # renamed account reads correctly in old entries too.
        query = query.outerjoin(
            models.User, models.AuditLog.performed_by == models.User.user_id
        ).filter(
            or_(
                models.AuditLog.entity_code.ilike(term),
                models.AuditLog.remarks.ilike(term),
                models.AuditLog.from_status.ilike(term),
                models.AuditLog.to_status.ilike(term),
                models.User.first_name.ilike(term),
                models.User.last_name.ilike(term),
                models.User.username.ilike(term),
            )
        )

    total = query.count()

    rows = (
        # joinedload, not a lazy relationship: without it each row would fetch
        # its own user, turning one page into fifty round trips.
        query.options(joinedload(models.AuditLog.performer))
        .order_by(models.AuditLog.audit_id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    items = []
    for row in rows:
        out = schemas.AuditLogOut.model_validate(row)
        out.performed_by_name = _display_name(row.performer)
        items.append(out)

    return schemas.AuditLogPage(total=total, items=items)
