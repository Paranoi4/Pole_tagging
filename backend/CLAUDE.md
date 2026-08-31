# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

FastAPI + SQLAlchemy + PostgreSQL backend for "Poletagging" — pre-generated, encoded physical tags for distribution-utility poles. It covers auth, user/role administration, and the pole-tagging domain (distribution utilities, work orders, batches, tags, cities, crews). The consumer is the Flutter app in `../frontend`.

## Commands

```bash
# Install (run from backend/)
pip install -r requirements.txt

# Run the dev server — MUST be run from the backend/ directory (see Import layout below)
uvicorn main:app --reload

# Interactive API docs / manual endpoint testing
# http://localhost:8000/docs

# Run the one existing test (plain unittest, no pytest configured)
python -m unittest tests.test_user_role_org_code
```

There is no linter or formatter configured, and no test runner in `requirements.txt`. `tests/test_user_role_org_code.py` uses plain `unittest` against an in-memory SQLite engine and calls the route function directly rather than through `TestClient`, so it never touches Postgres. Follow that pattern for new tests — `TestClient(app)` would trigger `Base.metadata.create_all` against the real `DATABASE_URL` at import time.

If you do need `TestClient`, override the `get_db` dependency onto an in-memory SQLite engine. Two things are required for that to behave like Postgres: `poolclass=StaticPool` (otherwise each connection gets its own empty database and tables vanish), and a `connect` event issuing `PRAGMA foreign_keys=ON` (SQLite ignores foreign keys by default, so `ondelete="CASCADE"` silently leaves orphan rows).

`requirements.txt` is incomplete: `python-jose` (imported as `jose` in `utils/auth.py`) and `requests` (used in `router/auth.py`) are installed in the working environment but missing from the file. Add them when touching dependencies.

## Environment

`.env` in `backend/` (gitignored), loaded by both `config/database.py` and `config/config.py`:

- `DATABASE_URL` — PostgreSQL DSN. **Required, no default** — the app crashes at import if unset. Currently points at the shared AWS RDS dev instance (`appwardtech-db-devt...ap-southeast-1.rds.amazonaws.com`), database **`postgres`**.
- `SECRET_KEY`, `ALGORITHM`, `ACCESS_TOKEN_EXPIRE_MINUTES` / `ACCESS_TOKEN_EXPIRE_SECONDS` — JWT settings, all have fallbacks in `config/config.py`. Tokens currently last 30 minutes.
- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI` — optional; the Google endpoints return HTTP 500 with a config message when unset.
- `FRONTEND_URL` — where `/auth/google/callback` redirects, defaults to `http://localhost:3000`.

Keep exactly one `DATABASE_URL` line. Stacking several (a local one, a placeholder, a real one) silently uses the last, which has caused the app to read from the wrong database.

## Database location

The app talks to **database `postgres`, schema `pole_tagging`** on the shared RDS instance. `config/database.py` pins `connect_args={"options": "-csearch_path=pole_tagging"}` — that line, not the DSN, is what selects the schema. Models declare no `schema=`, so they follow `search_path` wherever it points.

`postgres` on that server hosts many sibling app schemas (`oms`, `eam`, `fms`, `lms`, …). Never widen `search_path` or write unqualified DDL that could land in `public` or someone else's schema.

The older `poletagging_db` database on the same server holds the pre-migration copy of the data. It is not read by the app and is kept only as a fallback.

## Architecture

Package layout under `backend/`: `main.py` at the root, plus `config/` (`config.py`, `database.py`), `models/` (`models.py` SQLAlchemy, `schemas.py` Pydantic v2), `router/` (11 modules), `utils/` (`auth.py`, `tag_encoding.py`), and `tests/`.

**Import layout.** Every module uses top-level absolute imports rooted at `backend/` — `from config.database import get_db`, `import models.models as models`, `from utils.auth import get_current_user`. There is no `backend.` prefix and no relative imports. The working directory must be `backend/` for anything to import; do not run from the repo root.

**Schema management.** `main.py` calls `Base.metadata.create_all(bind=engine)` at import. There is no Alembic setup, so `create_all` only creates missing tables — adding or altering a column, or adding a constraint, on an existing table requires manual SQL against the database. Plan for that when editing `models/models.py`.

**Hand-built schemas drift from the models.** The `pole_tagging` schema was created by hand, and `create_all` will not repair an existing table, so it arrived missing primary keys, unique constraints, `ON DELETE` actions, and correct nullability — and two foreign keys were attached to the wrong column entirely. Those have been fixed, but the lesson stands: after any hand-created or hand-edited table, diff the live schema against `Base.metadata` with SQLAlchemy's `inspect()` (columns, nullability, PKs, FKs *including* `ondelete`, and unique constraints) rather than trusting that column names lining up means the table is correct.

**Startup side effects.** `main.py` runs `seed_roles()` at import, inserting Admin / Printerman / Dispatcher for each of the three org codes (9 rows) if absent. It prints emoji, which raises `UnicodeEncodeError` on a Windows console using cp1252 — run with `PYTHONIOENCODING=utf-8` when driving the app from a script. Because the print sits inside the `try`, an encoding failure is caught and reported as a seeding error even when seeding succeeded.

**Data model.** Nine tables:

- `users` ↔ `roles` many-to-many through an explicit `user_roles` association model
- `distribution_utilities` (DUs) own `tags`, `batches`, `work_orders`, and `cities`
- `work_orders` group `batches`; `batches` claim `tags`
- `cities` contain `crews`; `users` optionally belong to a crew

Both `user_roles` relationships set `cascade="all, delete-orphan", passive_deletes=True`, which hands deletion to the database's `ondelete="CASCADE"` — without `passive_deletes` SQLAlchemy tries to NULL out `user_id`/`role_id` first and hits the `nullable=False` constraint. Deleting a role therefore strips it from every user silently.

`User.roles` is a Python property that walks `user_roles`, not a relationship — it is what populates `UserOut.roles` and what `require_role` reads, so it emits lazy loads per user and list endpoints are N+1 by construction.

**Multi-tenancy via `org_code`.** Every domain table carries a non-null `org_code`, one of `"NP"`, `"BP"`, `"MP"` (`OrgCode` literal in `models/schemas.py`). It is the tenant boundary: list and lookup handlers filter on `current_user.org_code`, and writes stamp it from the token holder rather than the request body. A missing filter leaks another utility's data, so add `org_code` to the `WHERE` clause of every new query and never accept it from the client outside `POST /auth/register`.

Note `roles` is scoped too — uniqueness is `(role_name, org_code)`, so "Admin" exists three times, once per org.

**Request/response flow.** Routers depend on `get_db` (per-request session from `config.database.SessionLocal`), mutate SQLAlchemy models directly, then return `schemas.XOut.model_validate(obj)`. All `*Out` schemas set `from_attributes=True`. There is no service or repository layer — business rules live inline in the route handlers.

**Uniqueness is enforced in handlers, not just the database.** Both create *and* update paths check for a clashing `username` / `email` / `role_name` / `du_code` before writing, so a clash returns 400 rather than surfacing the database's IntegrityError as a 500. Update paths compare against the row's current value so saving an unchanged field still works. Keep that pattern when adding fields with unique constraints.

## Auth

`utils/auth.py` owns bcrypt hashing (passlib `CryptContext`), JWT encode/decode (python-jose), and the two dependencies below. It is the only place that hashes — routers import `get_password_hash` from it.

- The JWT `sub` claim is the **username**, not `user_id`. `get_current_user` looks the user up by username, so changing a username invalidates that user's outstanding tokens.
- `get_current_user` re-checks `is_active` on **every** request, so deactivating an account takes effect immediately rather than when the token expires. Deactivated users get 403.
- `POST /auth/login` accepts **username or email** in the `username` field, and refuses accounts whose `auth_provider` is not `"local"`. Google-created rows hold a fixed placeholder password hash, so without that check anyone could log in as any Google user by sending that known string. A NULL `auth_provider` is treated as local so legacy rows are not locked out.
- **Login lockout:** 5 consecutive wrong passwords set `locked_until` to 5 minutes out and return 429. The lock is checked *before* the password is verified, so a locked account cannot be probed. An expired lock clears its own counter on the next attempt — no successful login required.

**Authorization is implemented.** `require_role(*names)` in `utils/auth.py` is a dependency factory that 403s unless the user holds at least one of the named roles (overlap, not exact match). Applied per-route via `dependencies=[Depends(require_role("Admin"))]`. The rough shape:

- **Admin only** — all of `/users`, `/roles`, `/user-roles`; create/update/delete on `/du`, `/work-orders`, `/cities`, `/crews`; delete on `/batches`
- **Printerman or Admin** — `POST /batches`
- **Any authenticated user** — reads on `/du`, `/batches`, `/work-orders`, `/cities`, `/crews`, all of `/tags`, and `/me`
- **Public** — everything under `/auth`

A freshly registered user has **no roles at all** and sees the frontend's `NoRolesScreen` until an Admin assigns one via `POST /user-roles`.

**Client-settable fields.** `auth_provider` and `google_id` are deliberately absent from `UserCreate` — the server sets them. `role_ids` lives on `UserCreateAdmin` (used by the Admin-only `POST /users`) and *not* on `UserCreate` (used by the public `POST /auth/register`), so nobody can grant themselves a role by signing up. Conversely `org_code` is on `UserCreate` (a self-registering user picks their org) but **not** on `UserCreateAdmin`, which takes the creating admin's org from the token. Making a field optional does not protect it; keeping it off the schema does.

## Tag encoding

`utils/tag_encoding.py` implements the Negros Power double-hex scheme: a 32-character alphabet (`0-9`, `A-Y` minus `I`, `O`, `X` — the shapes that misread on a physical tag) encoding a pole number into exactly 4 characters, prefixed with the DU code. 32⁴ = **1,048,576** codes per DU.

`POST /du` generates **all** of them in one request — `db.bulk_insert_mappings` of a million rows inside the create transaction. That is deliberate (tag codes are pre-allocated inventory, drawn down as batches are printed), but it makes DU creation slow and memory-hungry; do not casually add per-row work to that path.

`POST /batches` then claims `quantity` rows where `status='Available' AND batch_id IS NULL`, setting `batch_id`. It deliberately does **not** flip `status` to `Printed` — that happens later via the print flow (`PATCH /tags/{id}/status` or `PATCH /tags/bulk/status`).

Batch and work-order codes are auto-generated, not client-supplied: `BT-{du_code}-{year}-{0000}` and the equivalent for work orders, sequenced by counting existing rows for that DU and year. That count-then-insert is a race under concurrency.

## Endpoints

| Prefix | Module | Auth |
|---|---|---|
| `/auth` | `router/auth.py` — `/login`, `/register`, `/google/login`, `/google/callback` | public |
| `/me` | `router/me.py` — current user | bearer |
| `/users` | `router/users.py` — CRUD + `/users/username/{username}` | Admin |
| `/roles` | `router/roles.py` — CRUD | Admin |
| `/user-roles` | `router/user_roles.py` — `POST` assign, `DELETE /user/{user_id}/role/{role_id}` | Admin |
| `/du` | `router/du.py` — CRUD + `/{id}/stats`, `/{id}/deactivate`, `/{id}/reactivate` | read: bearer, write: Admin |
| `/work-orders` | `router/work_orders.py` — CRUD | read: bearer, write: Admin |
| `/batches` | `router/batches.py` — CRUD + `/{id}/tags`, `/{id}/status`, `/{id}/assign` | create: Printerman/Admin, delete: Admin |
| `/tags` | `router/tags.py` — `/available/{du_id}`, `/next/{du_id}`, `/stats/{du_id}`, `/{id}/status`, `/bulk/status` | bearer |
| `/cities` | `router/cities.py` — CRUD | read: bearer, write: Admin |
| `/crews` | `router/crews.py` — CRUD | read: bearer, write: Admin |

`POST /auth/login` returns `{access_token, token_type, user}`, where `user` is a full `UserOut` including `roles` — the client does not need a second call to learn its roles.

**Route paths.** Collection routes are declared as `""`, not `"/"` — the paths are `POST /users`, `GET /roles`, `POST /batches`. Keep that convention; switching to `"/"` changes the URL and triggers redirects for existing clients.

**Pagination.** List endpoints bound their query params: `skip` is `ge=0`, `limit` is `ge=1, le=100`. Out-of-range values return 422.

## Frontend contract

`../frontend/lib/config/api_config.dart` reads `API_BASE_URL` from `String.fromEnvironment`, defaulting to `http://localhost:8000`; override it at build time with `--dart-define=API_BASE_URL=...`. `../frontend/lib/services/api_services.dart` sends `Authorization: Bearer <token>`. Changing a route path or response shape here requires the matching edit there.

Note a live inconsistency: `/auth/google/callback` redirects to `FRONTEND_URL` (default `http://localhost:3000`), which does not correspond to the Flutter client's origin. Google sign-in is not wired end-to-end.

## Known rough edges

- CORS is `allow_origins=["*"]` with all methods and headers (`main.py`).
- `datetime.utcnow()` is used for timestamp defaults (`models/models.py`) and JWT `exp` (`utils/auth.py`). It is deprecated on the Python 3.14 runtime in use here and scheduled for removal.
- `user_roles` has no unique constraint on `(user_id, role_id)`. The handler checks before inserting, but that is a check-then-insert race.
- Batch and work-order code generation counts existing rows to pick the next sequence number — two concurrent creates can pick the same one.
- `google_id` has no unique constraint, so two rows could claim the same Google identity. The callback matches on **email**, not `google_id`, so this is currently inert.
- The Google-created user path derives `username` from the email local part with no collision handling — two accounts whose emails share a local part collide on the unique `username`. It also hardcodes `org_code="NP"`.
- `/auth/google/callback` returns the JWT in a redirect query string, where it lands in browser history and server logs.
- `verify_password` raises `UnknownHashError` (→ 500) if a row's stored hash is empty or malformed, rather than returning a clean 401.
- `POST /auth/register` and `POST /users` still duplicate the create-user logic.
- Passwords are capped at 72 characters in `UserBase` because bcrypt ignores anything beyond that; without the cap, two different long passwords sharing a 72-character prefix both authenticate.
- `models/schemas.py` carries a block of commented-out earlier schema definitions above the live ones — read past them.
- passlib logs `(trapped) error reading bcrypt version` / `module 'bcrypt' has no attribute '__about__'` on first hash. It is the known passlib 1.7 vs bcrypt 4.x mismatch — trapped and harmless, hashing works. Ignore it; it is not a symptom of anything.
