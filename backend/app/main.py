import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import chat, planner, study_groups, notifications

app = FastAPI(
    title="UpGrade API",
    description="AI-powered personalized study planner with Llama 3.3",
    version="1.0.0"
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
            "ai_planner": "available"
        }
    }
