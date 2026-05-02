import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
<<<<<<< HEAD
from app.api.routes import chat, planner
=======
from app.api.routes import chat, planner, tasks, profile
>>>>>>> origin/continue

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
<<<<<<< HEAD
=======
app.include_router(tasks.router, prefix="/api")
app.include_router(profile.router, prefix="/api")
>>>>>>> origin/continue

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
