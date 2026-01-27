from fastapi import FastAPI

app = FastAPI(
    title="UpGrade API",
    description="AI-powered personalized study planner",
    version="1.0.0"
)

@app.get("/")
def root():
    return {"message": "UpGrade backend is running"}

@app.get("/health")
def health_check():
    return {"status": "ok"}
