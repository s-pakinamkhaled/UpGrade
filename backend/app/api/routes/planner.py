"""
Study Plan Generator API Routes
Generates personalized study plans using Llama 3.3 via Groq API
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import sys
import os
import json
from dotenv import load_dotenv

# Load environment variables from backend/.env and ai/.env
current_dir = os.path.dirname(os.path.abspath(__file__))
# current_dir = backend/app/api/routes → 4 dirname calls = project root (UpGrade/)
project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(current_dir))))

backend_env = os.path.join(project_root, 'backend', '.env')
ai_env = os.path.join(project_root, 'ai', '.env')
load_dotenv(backend_env)
load_dotenv(ai_env)

# Add AI service to path
ai_path = os.path.join(project_root, 'ai')
sys.path.insert(0, ai_path)

try:
    from planner_llm.llm_client import GroqClient
    groq_client = GroqClient()
    print("✅ Planner service initialized successfully")
except Exception as e:
    print(f"⚠️  Warning: Could not initialize planner service: {e}")
    print(f"   AI path attempted: {ai_path}")
    groq_client = None

router = APIRouter(prefix="/plan", tags=["planner"])


# ── Pydantic Models ──────────────────────────────────────────────

class TaskInput(BaseModel):
    """Input task for plan generation"""
    id: str
    title: str
    courseName: Optional[str] = ""
    deadline: Optional[str] = None
    estimatedMinutes: Optional[int] = 60
    priority: Optional[str] = "medium"
    status: Optional[str] = "pending"
    description: Optional[str] = None
    assignedGrade: Optional[float] = None
    maxPoints: Optional[int] = None


class PlanRequest(BaseModel):
    """Request body for plan generation"""
    studentName: str = "Student"
    tasks: List[TaskInput]


class PlanItem(BaseModel):
    """Single item in the generated study plan"""
    taskTitle: str
    courseName: Optional[str] = ""
    suggestedDate: str
    suggestedTime: str
    hoursNeeded: float
    priority: str
    tip: str


class PlanResponse(BaseModel):
    """Response from plan generation"""
    success: bool
    studentName: Optional[str] = None
    generatedAt: Optional[str] = None
    items: Optional[List[PlanItem]] = None
    summary: Optional[str] = None
    error: Optional[str] = None


# ── Helper Functions ─────────────────────────────────────────────

_PRIORITY_RANK = {"urgent": 0, "high": 1, "medium": 2, "low": 3}


def _build_prompt(req: PlanRequest) -> str:
    """Build a detailed prompt listing each task for the LLM."""
    now = datetime.now()
    lines = [
        f"Today is {now.strftime('%A, %B %d, %Y')} at {now.strftime('%H:%M')}.",
        f"Student name: {req.studentName}.",
        "",
        "Here are the student's active tasks:",
        "",
    ]

    for t in req.tasks:
        days_left = "unknown"
        if t.deadline:
            try:
                dl = datetime.fromisoformat(t.deadline.replace("Z", "+00:00"))
                days_left = f"{(dl - now).days} days"
            except Exception:
                days_left = "unknown"

        priority_tag = f"[{(t.priority or 'medium').upper()}]"
        grade_info = ""
        if t.assignedGrade is not None and t.maxPoints is not None:
            grade_info = f" | Grade: {t.assignedGrade}/{t.maxPoints}"
        elif t.assignedGrade is not None:
            grade_info = f" | Grade: {t.assignedGrade}"

        lines.append(
            f"- {priority_tag} {t.title} | Course: {t.courseName or 'N/A'} "
            f"| Deadline: {t.deadline or 'none'} ({days_left} left) "
            f"| Est: {t.estimatedMinutes or 60} min | Status: {t.status or 'pending'}"
            f"{grade_info}"
        )

    lines += [
        "",
        "Instructions:",
        "1. Analyse the tasks above and create a realistic study plan spread across the coming days.",
        "2. Allocate study hours and suggest time windows (e.g. '14:00 – 16:00').",
        "3. Give one short, practical tip per task.",
        "4. Provide a 2-3 sentence summary of the plan.",
        "5. Respond with **valid JSON only** — no markdown fences, no extra text.",
        "",
        "Required JSON schema:",
        '{',
        '  "items": [',
        '    {',
        '      "taskTitle": "string",',
        '      "courseName": "string",',
        '      "suggestedDate": "YYYY-MM-DD",',
        '      "suggestedTime": "HH:MM – HH:MM",',
        '      "hoursNeeded": number,',
        '      "priority": "urgent|high|medium|low",',
        '      "tip": "string"',
        '    }',
        '  ],',
        '  "summary": "string"',
        '}',
    ]
    return "\n".join(lines)


# ── Endpoints ────────────────────────────────────────────────────

@router.post("/generate", response_model=PlanResponse)
async def generate_plan(req: PlanRequest):
    """
    Generate a personalized study plan from the student's tasks
    using Llama 3.3 via Groq API.
    """
    if not groq_client:
        raise HTTPException(status_code=503, detail="Planner service is not available")

    # Filter: keep only active (non-completed) tasks
    active_tasks = [t for t in req.tasks if (t.status or "pending") not in ("completed",)]
    if not active_tasks:
        raise HTTPException(status_code=400, detail="No active tasks to plan for")

    # Sort by priority rank then deadline (soonest first)
    def sort_key(t):
        rank = _PRIORITY_RANK.get((t.priority or "medium").lower(), 2)
        dl = t.deadline or "9999-12-31"
        return (rank, dl)

    active_tasks.sort(key=sort_key)

    # Trim to 15 most urgent tasks to stay within token window
    active_tasks = active_tasks[:15]
    req_trimmed = PlanRequest(studentName=req.studentName, tasks=active_tasks)

    prompt = _build_prompt(req_trimmed)

    system_message = (
        "You are an expert academic study planner. "
        "You always respond with valid JSON only — no markdown fences, no extra text."
    )

    messages = [
        {"role": "system", "content": system_message},
        {"role": "user", "content": prompt},
    ]

    try:
        response = groq_client.chat_completion(
            messages=messages,
            temperature=0.4,
            max_tokens=3000,
        )

        if "error" in response and not response.get("choices"):
            raise HTTPException(
                status_code=502,
                detail=f"Groq API error: {response.get('error', 'unknown')}"
            )

        content = response["choices"][0]["message"]["content"]

        # Strip markdown fences if the model added them
        content = content.strip()
        if content.startswith("```"):
            content = content.split("\n", 1)[-1]
        if content.endswith("```"):
            content = content.rsplit("```", 1)[0]
        content = content.strip()

        parsed = json.loads(content)

        items = [
            PlanItem(
                taskTitle=item.get("taskTitle", ""),
                courseName=item.get("courseName", ""),
                suggestedDate=item.get("suggestedDate", ""),
                suggestedTime=item.get("suggestedTime", ""),
                hoursNeeded=float(item.get("hoursNeeded", 1)),
                priority=item.get("priority", "medium"),
                tip=item.get("tip", ""),
            )
            for item in parsed.get("items", [])
        ]

        return PlanResponse(
            success=True,
            studentName=req.studentName,
            generatedAt=datetime.now().isoformat(),
            items=items,
            summary=parsed.get("summary", ""),
        )

    except json.JSONDecodeError:
        raise HTTPException(
            status_code=502,
            detail="Groq returned a non-JSON response. Please try again."
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Plan generation failed: {str(e)}"
        )


@router.get("/health")
async def planner_health():
    """Check if planner service is working"""
    if not groq_client:
        return {"status": "unavailable", "service": "none"}

    return {
        "status": "ok",
        "service": "llama-3.3-70b-versatile",
        "provider": "groq",
    }
