"""
LLM client for study planning.
"""
import httpx
import os
from typing import List, Dict, Any
from .prompt import create_planning_prompt
from .formatter import parse_llm_schedule, validate_schedule

class LLMClient:
    """Client for interacting with LLM services."""
    
    def __init__(self, api_key: str = None, base_url: str = None):
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")
        self.base_url = base_url or "https://api.openai.com/v1"
        self.model = "gpt-4"
    
    async def generate_schedule(
        self,
        tasks: List[Dict[str, Any]],
        constraints: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Generate a study schedule using LLM.
        
        Args:
            tasks: List of tasks to schedule
            constraints: User constraints
        
        Returns:
            Schedule dictionary
        """
        if not self.api_key:
            # Fallback to rule-based scheduling
            return self._fallback_schedule(tasks, constraints)
        
        prompt = create_planning_prompt(tasks, constraints)
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": self.model,
                        "messages": [
                            {"role": "system", "content": "You are an expert study planner."},
                            {"role": "user", "content": prompt}
                        ],
                        "temperature": 0.7
                    },
                    timeout=30.0
                )
                response.raise_for_status()
                result = response.json()
                content = result["choices"][0]["message"]["content"]
                
                schedule = parse_llm_schedule(content)
                if validate_schedule(schedule):
                    return schedule
                else:
                    return self._fallback_schedule(tasks, constraints)
        except Exception as e:
            print(f"LLM error: {e}")
            return self._fallback_schedule(tasks, constraints)
    
    def _fallback_schedule(self, tasks: List[Dict[str, Any]], constraints: Dict[str, Any]) -> Dict[str, Any]:
        """Fallback rule-based scheduling."""
        from datetime import datetime, timedelta
        
        schedule = {}
        current_date = datetime.now().date()
        hours_per_day = constraints.get("hours_per_day", 8.0)
        
        for task in sorted(tasks, key=lambda t: (t.get("priority", 0), t.get("due_date", ""))):
            hours_needed = task.get("estimated_hours", 1.0)
            days_needed = int(hours_needed / hours_per_day) + 1
            
            for day_offset in range(days_needed):
                date = current_date + timedelta(days=day_offset)
                date_str = date.isoformat()
                
                if date_str not in schedule:
                    schedule[date_str] = []
                
                schedule[date_str].append({
                    "task_id": task.get("id"),
                    "title": task.get("title"),
                    "hours": min(hours_per_day, hours_needed - (day_offset * hours_per_day))
                })
        
        return schedule

