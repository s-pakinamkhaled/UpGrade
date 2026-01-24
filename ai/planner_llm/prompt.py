"""
LLM prompt templates for study planning.
"""
import json
from typing import List, Dict, Any

def create_planning_prompt(tasks: List[Dict[str, Any]], constraints: Dict[str, Any]) -> str:
    """
    Create a prompt for LLM-based study planning.
    
    Args:
        tasks: List of tasks to schedule
        constraints: User constraints (available hours, preferences, etc.)
    
    Returns:
        Formatted prompt string
    """
    prompt = f"""You are an AI study planner. Create an optimal study schedule for the following tasks.

User Constraints:
- Available hours per day: {constraints.get('hours_per_day', 8)}
- Preferred study times: {constraints.get('preferred_times', 'anytime')}
- Start date: {constraints.get('start_date', 'today')}
- End date: {constraints.get('end_date', '30 days from now')}

Tasks to Schedule:
"""
    for i, task in enumerate(tasks, 1):
        prompt += f"""
{i}. {task.get('title', 'Untitled')}
   - Due date: {task.get('due_date', 'No due date')}
   - Estimated hours: {task.get('estimated_hours', 0)}
   - Priority: {task.get('priority', 0)}
   - Risk score: {task.get('risk_score', 0)}
"""
    
    prompt += """
Please create a detailed daily schedule that:
1. Respects due dates and priorities
2. Distributes work evenly
3. Accounts for task complexity and risk
4. Includes buffer time for unexpected delays

Return the schedule in JSON format with dates as keys and lists of scheduled tasks as values.
"""
    return prompt

def create_optimization_prompt(current_schedule: Dict[str, Any], new_task: Dict[str, Any]) -> str:
    """
    Create a prompt for optimizing an existing schedule with a new task.
    
    Args:
        current_schedule: Current study schedule
        new_task: New task to add
    
    Returns:
        Formatted prompt string
    """
    prompt = f"""Optimize the existing study schedule to accommodate a new task.

Current Schedule:
{json.dumps(current_schedule, indent=2)}

New Task:
- Title: {new_task.get('title', 'Untitled')}
- Due date: {new_task.get('due_date', 'No due date')}
- Estimated hours: {new_task.get('estimated_hours', 0)}
- Priority: {new_task.get('priority', 0)}

Please provide an updated schedule that integrates this new task optimally.
"""
    return prompt

