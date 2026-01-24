"""
JSON input/output formatting for LLM.
"""
import json
from typing import List, Dict, Any

def format_tasks_for_llm(tasks: List[Dict[str, Any]]) -> str:
    """
    Format tasks as JSON string for LLM input.
    
    Args:
        tasks: List of task dictionaries
    
    Returns:
        JSON string
    """
    return json.dumps(tasks, indent=2, default=str)

def parse_llm_schedule(response: str) -> Dict[str, Any]:
    """
    Parse LLM response into schedule dictionary.
    
    Args:
        response: LLM response string (should contain JSON)
    
    Returns:
        Schedule dictionary
    """
    try:
        # Try to extract JSON from response
        if "```json" in response:
            json_start = response.find("```json") + 7
            json_end = response.find("```", json_start)
            json_str = response[json_start:json_end].strip()
        elif "```" in response:
            json_start = response.find("```") + 3
            json_end = response.find("```", json_start)
            json_str = response[json_start:json_end].strip()
        else:
            json_str = response.strip()
        
        return json.loads(json_str)
    except json.JSONDecodeError:
        # Fallback: return empty schedule
        return {}

def validate_schedule(schedule: Dict[str, Any]) -> bool:
    """
    Validate that a schedule has the correct structure.
    
    Args:
        schedule: Schedule dictionary
    
    Returns:
        True if valid, False otherwise
    """
    if not isinstance(schedule, dict):
        return False
    
    # Check that values are lists
    for date, tasks in schedule.items():
        if not isinstance(tasks, list):
            return False
        for task in tasks:
            if not isinstance(task, dict):
                return False
            if "task_id" not in task and "title" not in task:
                return False
    
    return True

