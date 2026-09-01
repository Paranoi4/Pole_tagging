from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.exc import IntegrityError

from config.database import engine, Base, get_db
import models.models as models
from models.enums import OrgCode, RoleName
from router import (
    auth, me, users, roles, user_roles,
    du, work_orders, batches, tags, cities, crews, audit_log, stats,
)

Base.metadata.create_all(bind=engine)


def seed_roles() -> None:
    db = next(get_db())
    seeded = 0
    try:
        for org in OrgCode:
            for role in RoleName:
                existing = db.query(models.Role).filter(
                    models.Role.role_name == role.value,
                    models.Role.org_code == org.value,
                ).first()
                if not existing:
                    db.add(models.Role(role_name=role.value, org_code=org.value))
                    seeded += 1
        db.commit()
    except IntegrityError:
        db.rollback()
        seeded = 0
    except Exception as exc:
        print(f"WARNING: could not seed roles: {exc}")
        db.rollback()
        return
    finally:
        db.close()

    print(f"Roles ready ({seeded} created)." if seeded else "Roles ready.")


seed_roles()

app = FastAPI(title="Poletagging API")

# TODO: narrow to the Flutter client's origin before production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {"message": "Poletagging API is running"}


for router in (
    auth.router,
    me.router,
    users.router,
    roles.router,
    user_roles.router,
    du.router,
    work_orders.router,
    batches.router,
    tags.router,
    cities.router,
    crews.router,
    audit_log.router,
    stats.router,
):
    app.include_router(router)
