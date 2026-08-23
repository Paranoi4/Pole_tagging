# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

FastAPI + SQLAlchemy + PostgreSQL backend for "Poletagging". It currently implements only auth and user/role administration — there is no pole-tagging domain model yet. The consumer is the Flutter app in `../frontend`.

## Commands

```bash
# Install (run from backend/)
pip install -r requirements.txt

# Run the dev server — MUST be run from the backend/ directory (see Import layout below)
uvicorn main:app --reload

# Interactive API docs / manual endpoint testing
# http://localhost:8000/docs
```

There is no test suite, linter, or formatter configured, and no test runner in `requirements.txt`. If you add tests, use `pytest` and note that `TestClient(app)` triggers `Base.metadata.create_all` against the real `DATABASE_URL` at import time — point `DATABASE_URL` at a throwaway database first.

To exercise endpoints against a throwaway database without touching Postgres, override the `get_db` dependency onto an in-memory SQLite engine. Two things are required for that to behave like Postgres: `poolclass=StaticPool` (otherwise each connection gets its own empty database and tables vanish), and a `connect` event issuing `PRAGMA foreign_keys=ON` (SQLite ignores foreign keys by default, so `ondelete="CASCADE"` silently leaves orphan rows).

`requirements.txt` is incomplete: `python-jose` (imported as `jose` in `utils/auth.py`) and `requests` (used in `router/auth.py`) are installed in the working environment but missing from the file. Add them when touching dependencies.

## Environment

`.env` in `backend/` (gitignored), loaded by both `config/database.py` and `config/config.py`:

- `DATABASE_URL` — PostgreSQL DSN. **Required, no default** — the app crashes at import if unset. The engine pins `search_path=pole_tagging`.
- `SECRET_KEY`, `ALGORITHM`, `ACCESS_TOKEN_EXPIRE_MINUTES` / `ACCESS_TOKEN_EXPIRE_SECONDS` — JWT settings, all have fallbacks in `config/config.py`. Tokens currently last 30 minutes.
- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI` — optional; the Google endpoints return HTTP 500 with a config message when unset.

## Architecture

Package layout under `backend/`: `main.py` at the root, plus `config/` (`config.py`, `database.py`), `models/` (`models.py` SQLAlchemy, `schemas.py` Pydantic v2), `router/`, and `utils/`.

**Import layout.** Every module uses top-level absolute imports rooted at `backend/` — `from config.database import get_db`, `import models.models as models`, `from utils.auth import get_current_user`. There is no `backend.` prefix and no relative imports. The working directory must be `backend/` for anything to import; do not run from the repo root.

**Schema management.** `main.py` calls `Base.metadata.create_all(bind=engine)` at import. There is no Alembic setup, so `create_all` only creates missing tables — adding or altering a column, or adding a constraint, on an existing table requires manual SQL against the database. Plan for that when editing `models/models.py`.

**Data model.** `User` ↔ `Role` many-to-many through an explicit `UserRole` association model (three tables: `users`, `roles`, `user_roles`). Both `user_roles` relationships set `cascade="all, delete-orphan", passive_deletes=True`, which hands deletion to the database's `ondelete="CASCADE"` — without `passive_deletes` SQLAlchemy tries to NULL out `user_id`/`role_id` first and hits the `nullable=False` constraint. Deleting a role therefore strips it from every user silently.

`User.roles` is a Python property that walks `user_roles`, not a relationship — it is what populates `UserOut.roles`, and it emits lazy loads per user, so list endpoints are N+1 by construction.

**Request/response flow.** Routers depend on `get_db` (per-request session from `config.database.SessionLocal`), mutate SQLAlchemy models directly, then return `schemas.XOut.model_validate(obj)`. All `*Out` schemas set `from_attributes=True`. There is no service or repository layer — business rules (uniqueness checks, existence checks) live inline in the route handlers.

**Uniqueness is enforced in handlers, not just the database.** Both create *and* update paths check for a clashing `username` / `email` / `role_name` before writing, so a clash returns 400 rather than surfacing the database's IntegrityError as a 500. Update paths compare against the row's current value so saving an unchanged field still works. Keep that pattern when adding fields with unique constraints.

**Auth.** `utils/auth.py` owns bcrypt hashing (passlib `CryptContext`) and JWT encode/decode (python-jose). It is the only place that hashes — routers import `get_password_hash` from it. Things to know:

- The JWT `sub` claim is the **username**, not `user_id`. `get_current_user` looks the user up by username, so changing a username invalidates that user's outstanding tokens.
- `get_current_user` re-checks `is_active` on **every** request, so deactivating an account takes effect immediately rather than when the token expires. Deactivated users get 403.
- `POST /auth/login` refuses accounts whose `auth_provider` is not `"local"`. Google-created rows hold a fixed placeholder password hash, so without that check anyone could log in as any Google user by sending that known string. A NULL `auth_provider` is treated as local so legacy rows are not locked out.
- Protection is applied per-router via `dependencies=[Depends(get_current_user)]` on the `APIRouter` (`users`, `roles`, `user_roles`). `/auth/*` is public; `/me` declares the dependency on the handler because it needs the user object.

**Authorization is not implemented.** Roles are stored and returned but never checked. Any authenticated user can create/update/delete any user, role, or role assignment. Treat "add a role check" as new work, not a fix to existing plumbing.

**Client-settable fields.** `auth_provider` and `google_id` are deliberately absent from `UserCreate` — the server sets them. `role_ids` lives on `UserCreateAdmin` (used by the token-protected `POST /users`) and *not* on `UserCreate` (used by the public `POST /auth/register`), so nobody can grant themselves a role by signing up. Making a field optional does not protect it; keeping it off the public schema does. Apply the same rule to any future field the server is meant to determine.

**Route paths.** Collection routes are declared as `""`, not `"/"` — the paths are `POST /users`, `GET /roles`, `POST /user-roles`. Keep that convention; switching to `"/"` changes the URL and triggers redirects for existing clients.

**Pagination.** List endpoints bound their query params: `skip` is `ge=0`, `limit` is `ge=1, le=100`. Out-of-range values return 422.

## Endpoints

| Prefix | Module | Auth |
|---|---|---|
| `/auth` | `router/auth.py` — `/login`, `/register`, `/google/login`, `/google/callback` | public |
| `/me` | `router/me.py` — current user | bearer |
| `/users` | `router/users.py` — CRUD + `/users/username/{username}` | bearer |
| `/roles` | `router/roles.py` — CRUD | bearer |
| `/user-roles` | `router/user_roles.py` — `POST` assign, `DELETE /user/{user_id}/role/{role_id}` remove | bearer |

`POST /auth/login` returns `{access_token, token_type, user}`, where `user` is a full `UserOut` including `roles` — the client does not need a second call to learn its roles.

`POST /users` accepts an optional `role_ids: list[int]`, creating the user and its `user_roles` rows in a single transaction (`db.flush()` to obtain `user_id`, then one `db.commit()`). Unknown role IDs are rejected with 404 *before* the user is inserted, so a bad ID never leaves a roleless user behind. `POST /auth/register` is the near-duplicate public path and ignores roles entirely.

Reading a user's roles goes through `GET /users/{id}` or the login response; `/user-roles` only writes.

## Frontend contract

`../frontend/lib/services/api_services.dart` hardcodes `baseUrl = 'http://localhost:8000'` and sends `Authorization: Bearer <token>`. Changing a route path or response shape here requires the matching edit there. The Flutter client does not call `/user-roles` at all.

Note a live inconsistency: `/auth/google/callback` redirects to `http://localhost:3000/login?...` (`router/auth.py`), which does not correspond to the Flutter client's origin. Google sign-in is not wired end-to-end.

## Known rough edges

- CORS is `allow_origins=["*"]` with all methods and headers (`main.py`).
- `datetime.utcnow()` is used for timestamp defaults (`models/models.py`) and JWT `exp` (`utils/auth.py`). It is deprecated on the Python 3.14 runtime in use here and scheduled for removal.
- `user_roles` has no unique constraint on `(user_id, role_id)`. The handler checks before inserting, but that is a check-then-insert race. Adding the constraint needs manual SQL.
- `google_id` has no unique constraint, so two rows could claim the same Google identity. The callback matches on **email**, not `google_id`, so this is currently inert.
- The Google-created user path derives `username` from the email local part with no collision handling — two accounts whose emails share a local part collide on the unique `username`.
- `/auth/google/callback` returns the JWT in a redirect query string, where it lands in browser history and server logs.
- `verify_password` raises `UnknownHashError` (→ 500) if a row's stored hash is empty or malformed, rather than returning a clean 401.
- `POST /auth/register` and `POST /users` still duplicate the create-user logic.
- Passwords are capped at 72 characters in `UserCreate` because bcrypt ignores anything beyond that; without the cap, two different long passwords sharing a 72-character prefix both authenticate.
