"""
Risk assessment service - connects to AI.
"""
import httpx
from typing import List, Dict, Any
from app.models.task import Task
from app.core.config import settings

async def calculate_risk_scores(tasks: List[Task]) -> Dict[int, float]:
    """
    Calculate risk scores for tasks using AI service.
    
    Args:
        tasks: List of tasks to assess
    
    Returns:
        Dictionary mapping task_id to risk_score
    """
    if not settings.ai_service_url:
        # Fallback to rule-based risk calculation
        return _rule_based_risk(tasks)
    
    try:
        async with httpx.AsyncClient() as client:
            # Prepare task data for AI service
            task_data = [
                {
                    "id": task.id,
                    "due_date": task.due_date.isoformat() if task.due_date else None,
                    "estimated_hours": task.estimated_hours,
                    "priority": task.priority,
                    "status": task.status
                }
                for task in tasks
            ]
            
            response = await client.post(
                f"{settings.ai_service_url}/risk/calculate",
                json={"tasks": task_data}
            )
            response.raise_for_status()
            result = response.json()
            return {int(k): float(v) for k, v in result.items()}
    except Exception as e:
        # Fallback to rule-based
        return _rule_based_risk(tasks)

def _rule_based_risk(tasks: List[Task]) -> Dict[int, float]:
    """Fallback rule-based risk calculation."""
    from datetime import datetime, timedelta
    risk_scores = {}
    
    for task in tasks:
        risk = 0.0
        
        # Time-based risk
        if task.due_date:
            days_until_due = (task.due_date - datetime.now()).days
            if days_until_due < 0:
                risk += 0.5  # Overdue
            elif days_until_due < 3:
                risk += 0.4
            elif days_until_due < 7:
                risk += 0.2
        
        # Priority-based risk
        if task.priority >= 8:
            risk += 0.3
        elif task.priority >= 5:
            risk += 0.1
        
        # Estimated hours risk
        if task.estimated_hours and task.estimated_hours > 10:
            risk += 0.2
        
        risk_scores[task.id] = min(risk, 1.0)
    
    return risk_scores

