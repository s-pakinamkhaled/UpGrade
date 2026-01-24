"""
FastAPI entry point for the upgrade backend.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import auth, tasks, planner, classroom

app = FastAPI(title="Upgrade API", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(tasks.router)
app.include_router(planner.router)
app.include_router(classroom.router)

@app.get("/")
async def root():
    return {"message": "Upgrade API"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

