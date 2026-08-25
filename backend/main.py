from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from config.database import engine, Base, get_db
import models.models as models

# Create tables
Base.metadata.create_all(bind=engine)


# ===== SEED FIXED ROLES =====
# Roles are fixed for this system (Admin, Printerman, Dispatcher) — there is
# no "create role" UI. This just makes sure the three rows exist on startup,
# so /user-roles has something valid to assign against on a fresh database.
def seed_roles():
    db = next(get_db())
    try:
        existing = {r.role_name for r in db.query(models.Role).all()}
        for role_name in ("Admin", "Printerman", "Dispatcher"):
            if role_name not in existing:
                db.add(models.Role(role_name=role_name))
        db.commit()
    finally:
        db.close()

seed_roles()

# Import routers
from router import users, roles, auth, user_roles, me

app = FastAPI(title="Poletagging API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {"message": "Poletagging API is running"}

# Include routers
app.include_router(auth.router)  
app.include_router(me.router)
app.include_router(users.router)
app.include_router(roles.router)
app.include_router(user_roles.router)