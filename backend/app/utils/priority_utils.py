"""
Priority utility functions.
"""
from typing import List
from app.models.task import Task

def calculate_priority(task: Task) -> int:
    """
    Calculate priority score for a task (0-10).
    
    Higher score = higher priority.
    """
    priority = 0
    
    # Due date urgency
    if task.due_date:
        days_until = (task.due_date - task.created_at).days
        if days_until < 1:
            priority += 5
        elif days_until < 3:
            priority += 4
        elif days_until < 7:
            priority += 3
        elif days_until < 14:
            priority += 2
        else:
            priority += 1
    
    # Risk score
    if task.risk_score:
        priority += int(task.risk_score * 3)
    
    # Estimated hours (longer tasks get slightly higher priority)
    if task.estimated_hours and task.estimated_hours > 5:
        priority += 1
    
    return min(priority, 10)

def sort_by_priority(tasks: List[Task]) -> List[Task]:
    """Sort tasks by calculated priority."""
    return sorted(tasks, key=lambda t: calculate_priority(t), reverse=True)

