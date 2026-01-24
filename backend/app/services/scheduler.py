"""
Core scheduling logic.
"""
from typing import List, Dict, Any
from datetime import datetime, timedelta
from app.models.task import Task

def schedule_tasks(tasks: List[Task], available_hours_per_day: float = 8.0) -> Dict[str, Any]:
    """
    Schedule tasks based on priority, due dates, and available time.
    
    Args:
        tasks: List of tasks to schedule
        available_hours_per_day: Hours available for studying per day
    
    Returns:
        Dictionary with scheduled tasks by date
    """
    # Sort tasks by priority and due date
    sorted_tasks = sorted(tasks, key=lambda t: (t.priority, t.due_date or datetime.max))
    
    schedule = {}
    current_date = datetime.now().date()
    
    for task in sorted_tasks:
        if task.status == "completed":
            continue
            
        hours_needed = task.estimated_hours or 1.0
        days_needed = int(hours_needed / available_hours_per_day) + 1
        
        # Assign task to days
        for day_offset in range(days_needed):
            date = current_date + timedelta(days=day_offset)
            date_str = date.isoformat()
            
            if date_str not in schedule:
                schedule[date_str] = []
            
            schedule[date_str].append({
                "task_id": task.id,
                "title": task.title,
                "hours": min(available_hours_per_day, hours_needed - (day_offset * available_hours_per_day))
            })
    
    return schedule

