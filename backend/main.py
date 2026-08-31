from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from config.database import engine, Base, get_db
import models.models as models

# ============================================================
# CREATE MISSING TABLES ONLY
# ============================================================
# print("Creating any missing tables...")
Base.metadata.create_all(bind=engine)
# ============================================================

# ===== SEED FIXED ROLES =====
def seed_roles():
    db = next(get_db())
    try:
        orgs = ["NP", "BP", "MP"]
        for org in orgs:
            for role_name in ("Admin", "Printerman", "Dispatcher"):
                existing = db.query(models.Role).filter(
                    models.Role.role_name == role_name,
                    models.Role.org_code == org
                ).first()
                if not existing:
                    db.add(models.Role(role_name=role_name, org_code=org))
        db.commit()
        print("✅ Roles seeded successfully!")
    except Exception as e:
        print(f"⚠️ Error seeding roles: {e}")
        db.rollback()
    finally:
        db.close()

seed_roles()

# Import routers
from router import users, roles, auth, user_roles, me, du, tags, batches, work_orders, crews, cities

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
app.include_router(du.router)
app.include_router(tags.router)
app.include_router(batches.router)
app.include_router(work_orders.router)
app.include_router(crews.router)
app.include_router(cities.router) 