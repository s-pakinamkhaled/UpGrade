"""
Rule-based risk assessment (v1 fallback).
"""
from typing import Dict, Any
from datetime import datetime

def calculate_risk_rules(task: Dict[str, Any]) -> float:
    """
    Calculate risk score using rule-based approach.
    
    Args:
        task: Task dictionary
    
    Returns:
        Risk score between 0.0 and 1.0
    """
    risk = 0.0
    
    # Time-based risk
    if task.get("due_date"):
        due_date = datetime.fromisoformat(task["due_date"])
        days_until = (due_date - datetime.now()).days
        
        if days_until < 0:
            risk += 0.5  # Overdue
        elif days_until < 1:
            risk += 0.4
        elif days_until < 3:
            risk += 0.3
        elif days_until < 7:
            risk += 0.2
    
    # Priority-based risk
    priority = task.get("priority", 0)
    if priority >= 8:
        risk += 0.3
    elif priority >= 5:
        risk += 0.15
    elif priority >= 3:
        risk += 0.1
    
    # Estimated hours risk
    estimated_hours = task.get("estimated_hours", 0)
    if estimated_hours > 20:
        risk += 0.2
    elif estimated_hours > 10:
        risk += 0.1
    
    # Status risk
    if task.get("status") == "in_progress":
        risk += 0.1
    
    return min(risk, 1.0)

