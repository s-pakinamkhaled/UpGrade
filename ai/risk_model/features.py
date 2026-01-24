"""
Feature engineering for risk model.
"""
from typing import List, Dict, Any
from datetime import datetime

def extract_features(task: Dict[str, Any]) -> List[float]:
    """
    Extract features from a task for risk prediction.
    
    Args:
        task: Task dictionary with fields like due_date, estimated_hours, etc.
    
    Returns:
        List of feature values
    """
    features = []
    
    # Time-based features
    if task.get("due_date"):
        due_date = datetime.fromisoformat(task["due_date"])
        days_until = (due_date - datetime.now()).days
        features.append(days_until)
        features.append(1.0 if days_until < 0 else 0.0)  # Is overdue
        features.append(1.0 if days_until < 3 else 0.0)  # Is urgent
    else:
        features.extend([999.0, 0.0, 0.0])
    
    # Task characteristics
    features.append(task.get("estimated_hours", 0.0))
    features.append(task.get("priority", 0.0))
    features.append(1.0 if task.get("status") == "in_progress" else 0.0)
    
    # Historical features (if available)
    features.append(task.get("actual_hours", 0.0))
    if task.get("estimated_hours") and task.get("estimated_hours") > 0:
        hours_ratio = task.get("actual_hours", 0.0) / task.get("estimated_hours")
        features.append(hours_ratio)
    else:
        features.append(0.0)
    
    return features

