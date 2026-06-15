import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import chat, planner, tasks, profile , study_groups, notifications, app_notifications
from app.services.deadline_scheduler import (
    is_scheduler_running,
    shutdown_deadline_scheduler,
    start_deadline_scheduler,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    start_deadline_scheduler()
    yield
    shutdown_deadline_scheduler()


app = FastAPI(
    title="UpGrade API",
    description="AI-powered personalized study planner with Llama 3.3",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(chat.router, prefix="/api")
app.include_router(planner.router, prefix="/api")
app.include_router(study_groups.router, prefix="/api")
app.include_router(notifications.router, prefix="/api")
app.include_router(app_notifications.router, prefix="/api")
app.include_router(tasks.router, prefix="/api")
app.include_router(profile.router, prefix="/api")

@app.get("/")
def root():
    return {
        "message": "UpGrade backend is running",
        "version": "1.0.0",
        "ai_model": "Llama 3.3 (Groq)"
    }

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.get("/api/health")
def api_health():
    return {
        "status": "ok",
        "services": {
            "backend": "running",
            "ai_chat": "available",
            "ai_planner": "available",
            "deadline_scheduler": "running" if is_scheduler_running() else "stopped",
        }
    }
