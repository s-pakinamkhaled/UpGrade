"""
AI service - FastAPI service for AI endpoints.
"""
from fastapi import FastAPI, HTTPException
from typing import List, Dict, Any
from risk_model.model import RiskModel
from planner_llm.llm_client import LLMClient
import os

app = FastAPI(title="Upgrade AI Service", version="1.0.0")

# Initialize models
risk_model = RiskModel()
llm_client = LLMClient(api_key=os.getenv("OPENAI_API_KEY"))

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.post("/risk/calculate")
async def calculate_risk(request: Dict[str, Any]) -> Dict[str, int]:
    """
    Calculate risk scores for tasks.
    
    Request body:
    {
        "tasks": [
            {
                "id": 1,
                "due_date": "2024-01-15T23:59:59",
                "estimated_hours": 5.0,
                "priority": 8,
                "status": "pending"
            }
        ]
    }
    """
    tasks = request.get("tasks", [])
    if not tasks:
        raise HTTPException(status_code=400, detail="No tasks provided")
    
    risk_scores = risk_model.predict_batch(tasks)
    return risk_scores

@app.post("/planner/generate")
async def generate_schedule(request: Dict[str, Any]) -> Dict[str, Any]:
    """
    Generate a study schedule using LLM.
    
    Request body:
    {
        "tasks": [...],
        "constraints": {
            "hours_per_day": 8.0,
            "start_date": "2024-01-01",
            "end_date": "2024-01-31"
        }
    }
    """
    tasks = request.get("tasks", [])
    constraints = request.get("constraints", {})
    
    if not tasks:
        raise HTTPException(status_code=400, detail="No tasks provided")
    
    schedule = await llm_client.generate_schedule(tasks, constraints)
    return {"schedule": schedule}

