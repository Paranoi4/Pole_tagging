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

    Two of these take a tag out of circulation rather than describing progress,
    and both require a remark saying why — see `STATUSES_REQUIRING_REMARKS`:

    * LOST_PRINTED — the tag reached paper but never reached a pole. Its code is
      re-printable, which is why it is not simply "Lost": what was lost is the
      printed article, not the code.
    * JAM_PAPER — the paper jammed and the tag never printed properly. Kept
      apart from LOST_PRINTED even though both send the code round again: one is
      a printer fault and the other is a tag going missing, and counting them
      together hides which of the two is actually costing you.
    * DO_NOT_USE — the generated four-character code reads as something obscene
      or otherwise unusable on a pole in public. The code is withdrawn for good;
      nothing reprints it.
    """

    AVAILABLE = "Available"
    PRINTED = "Printed"
    DISPATCHED = "Dispatched"
    INSTALLED = "Installed"
    LOST_PRINTED = "Lost Printed"
    JAM_PAPER = "Jam Paper"
    DO_NOT_USE = "Do Not Use"
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


class AuditEntity(str, Enum):
    """What an audit row is about.

    Rows are written for the thing the action was performed *on*, not for every
    row it touched: dispatching a batch is one BATCH entry, not one TAG entry per
    tag in it. Marking tags lost from the print sheet is the other way round —
    each tag was individually chosen, so each gets its own TAG entry.
    """

    TAG = "tag"
    BATCH = "batch"

    def __str__(self) -> str:
        return self.value


def _pattern(enum_cls) -> str:
    """Regex for a `Query(..., pattern=...)` that accepts exactly this enum's
    values, built from the enum so the two can never drift apart."""
    return "^(" + "|".join(member.value for member in enum_cls) + ")$"


TAG_STATUS_PATTERN = _pattern(TagStatus)
BATCH_STATUS_PATTERN = _pattern(BatchStatus)

# Statuses that withdraw a tag from use rather than moving it along the normal
# print-and-install path. Each one has to say why: a code recorded as lost or
# unusable with no reason behind it is a code nobody can account for when the
# batch is audited. Enforced in the handler, not just in the UI, so every caller
# obeys it.
STATUSES_REQUIRING_REMARKS = frozenset(
    {
        TagStatus.LOST_PRINTED.value,
        TagStatus.JAM_PAPER.value,
        TagStatus.DO_NOT_USE.value,
    }
)

# Statuses whose code still has to reach paper: never printed, printed and lost,
# or ruined by a jam. The print sheet and batch creation both key off this, so
# the rule lives here rather than being spelled out in each.
PRINTABLE_TAG_STATUSES = frozenset(
    {
        TagStatus.AVAILABLE.value,
        TagStatus.LOST_PRINTED.value,
        TagStatus.JAM_PAPER.value,
    }
)

# Statuses nothing may set yet. Installing a tag is a thing a field crew does at
# the pole, and that part of the app does not exist — no screen, no crew login,
# no user linked to a crew — so any request claiming a tag is installed is a
# mistake rather than a record. Remove INSTALLED from here when the field-crew
# flow is built.
UNREACHABLE_TAG_STATUSES = frozenset({TagStatus.INSTALLED.value})

# Transitions the system refuses, and the reason the caller is given.
#
# A deny-list rather than a full allow-matrix on purpose: it names only what is
# known to be wrong, so a sensible combination nobody has thought of yet still
# works instead of being blocked by omission.
FORBIDDEN_TAG_TRANSITIONS: dict[tuple[str, str], str] = {
    # A tag that never reached paper cannot be a lost print. Allowing it also put
    # a pool tag straight into the reprint queue, since Lost Printed is
    # printable.
    (TagStatus.AVAILABLE.value, TagStatus.LOST_PRINTED.value):
        "a tag that has never been printed cannot be a lost print",
    # Same reasoning: a tag still sitting in the pool has never been through a
    # printer, so it cannot have jammed in one.
    (TagStatus.AVAILABLE.value, TagStatus.JAM_PAPER.value):
        "a tag that has never been printed cannot have jammed",
    # Paper cannot be un-printed. The printed article exists; returning the code
    # to the pool as unprinted would hand it out for a second pole.
    (TagStatus.PRINTED.value, TagStatus.AVAILABLE.value):
        "a printed tag cannot go back to the pool as unprinted",
    # Pulling a batch back is a batch-level operation: it clears the crew and the
    # dispatch time as well as the tag statuses. Doing it a tag at a time leaves
    # the batch claiming it is still with a crew.
    (TagStatus.DISPATCHED.value, TagStatus.PRINTED.value):
        "return the batch instead, which also clears its crew",
    (TagStatus.DISPATCHED.value, TagStatus.AVAILABLE.value):
        "return the batch instead, which also clears its crew",
}
