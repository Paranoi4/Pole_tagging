from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from config.database import engine, Base
import models.models as models

# Create tables
Base.metadata.create_all(bind=engine)

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