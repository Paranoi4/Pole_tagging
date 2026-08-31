from enum import Enum


class OrgCode(str, Enum):
    """The organizations this deployment serves.

    Single source of truth: adding an organization means adding a member here,
    not editing the Pydantic schemas, the role seeder, and the Google callback
    separately. Subclassing `str` keeps members usable anywhere a plain string
    is expected — comparisons, query filters, and SQLAlchemy binds — but write
    `.value` when handing one to the database so the stored text is "NP" and
    never "OrgCode.NP".
    """

    NP = "NP"
    BP = "BP"
    MP = "MP"

    def __str__(self) -> str:
        return self.value


class RoleName(str, Enum):
    """The roles the code itself enforces.

    These are seeded per organization at startup and named in every
    `require_role(...)` guard, so the strings here and the `roles.role_name`
    column have to agree exactly — renaming one of these rows in the database
    would silently stop the matching guard from ever passing. Roles an admin
    creates beyond these are ordinary data and do not belong here.
    """

    ADMIN = "Admin"
    PRINTERMAN = "Printerman"
    DISPATCHER = "Dispatcher"

    def __str__(self) -> str:
        return self.value


class TagStatus(str, Enum):
    """Where a physical tag is in its life.

    Anything other than AVAILABLE means the tag has left the shelf and records
    something that happened in the field, which is why a batch holding one of
    those cannot be deleted.
    """

    AVAILABLE = "Available"
    PRINTED = "Printed"
    DISPATCHED = "Dispatched"
    INSTALLED = "Installed"
    LOST = "Lost"
    DAMAGED = "Damaged"

    def __str__(self) -> str:
        return self.value


class BatchStatus(str, Enum):
    """Where a batch is in the print-and-hand-over flow."""

    PENDING = "Pending"
    PRINTED = "Printed"
    DISPATCHED = "Dispatched"

    def __str__(self) -> str:
        return self.value


def _pattern(enum_cls) -> str:
    """Regex for a `Query(..., pattern=...)` that accepts exactly this enum's
    values, built from the enum so the two can never drift apart."""
    return "^(" + "|".join(member.value for member in enum_cls) + ")$"


TAG_STATUS_PATTERN = _pattern(TagStatus)
BATCH_STATUS_PATTERN = _pattern(BatchStatus)
