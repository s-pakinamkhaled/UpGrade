from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import chat

app = FastAPI(
    title="UpGrade API",
    description="AI-powered personalized study planner with Llama 3.3",
    version="1.0.0"
)

# Enable CORS for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your frontend URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(chat.router, prefix="/api")

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
            "ai_chat": "available"
        }
    }
