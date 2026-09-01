"""Writing and reading audit entries.

One place that knows how to append to `audit_log`, so the routers say *what
happened* and never assemble rows themselves.

Nothing that writes here commits. Entries are staged on the caller's session and
go out with the change they describe, so a rolled-back update takes its log entry
with it and the two can never disagree.
"""

from datetime import datetime
from typing import Optional, Sequence

from sqlalchemy.orm import Session

import models.models as models
from models.enums import AuditEntity


def record(
    db: Session,
    *,
    entity_type: AuditEntity,
    entity_id: int,
    entity_code: Optional[str],
    org_code: str,
    to_status: Optional[str],
    from_status: Optional[str] = None,
    remarks: Optional[str] = None,
    performed_by: Optional[int] = None,
) -> None:
    """Stage one audit entry.

    `from_status` is left null for a creation, where there was no prior state,
    and `to_status` for a deletion, where there is no state afterwards.
    """
    db.add(
        models.AuditLog(
            entity_type=str(entity_type),
            entity_id=entity_id,
            entity_code=entity_code,
            org_code=org_code,
            from_status=from_status,
            to_status=to_status,
            remarks=remarks,
            performed_by=performed_by,
        )
    )


def record_many(
    db: Session,
    *,
    entity_type: AuditEntity,
    changes: Sequence[tuple[int, Optional[str], Optional[str]]],
    org_code: str,
    to_status: Optional[str],
    remarks: Optional[str] = None,
    performed_by: Optional[int] = None,
) -> None:
    """Stage one entry per entity, in a single INSERT.

    `changes` is (entity_id, entity_code, from_status) triples — each entity
    carries its own code and its own previous status, since a bulk update can
    start from a mix of them.

    Uses bulk_insert_mappings so a hundred entries cost one round trip rather
    than a hundred. At ~55ms per round trip to the database that is the
    difference between a bulk update staying fast and becoming unusable.
    """
    if not changes:
        return

    now = datetime.utcnow()
    db.bulk_insert_mappings(
        models.AuditLog,
        [
            {
                "entity_type": str(entity_type),
                "entity_id": entity_id,
                "entity_code": entity_code,
                "org_code": org_code,
                "from_status": from_status,
                "to_status": to_status,
                "remarks": remarks,
                "performed_by": performed_by,
                # bulk_insert_mappings bypasses column defaults, so the
                # timestamp has to be supplied here.
                "created_at": now,
            }
            for entity_id, entity_code, from_status in changes
        ],
    )


def history(
    db: Session,
    *,
    entity_type: AuditEntity,
    entity_id: int,
    org_code: str,
    limit: int = 100,
) -> list[models.AuditLog]:
    """One entity's changes, newest first, scoped to the caller's org."""
    return (
        db.query(models.AuditLog)
        .filter(
            models.AuditLog.entity_type == str(entity_type),
            models.AuditLog.entity_id == entity_id,
            models.AuditLog.org_code == org_code,
        )
        .order_by(models.AuditLog.audit_id.desc())
        .limit(limit)
        .all()
    )
