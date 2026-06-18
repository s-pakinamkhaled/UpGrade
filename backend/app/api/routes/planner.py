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


ai_path = os.path.join(project_root, 'ai') # ai_service 
sys.path.insert(0, ai_path)

try:
    from planner_llm.llm_client import GroqClient
    groq_client = GroqClient()
    print("[OK] Planner service initialized successfully")
except Exception as e:
    print(f"[WARN] Could not initialize planner service: {e}")
    print(f"   AI path attempted: {ai_path}")
    groq_client = None

try:
    from task_filter import filter_real_tasks as _filter_real_tasks
    print("[OK] Task filter loaded")
except ImportError:
    # Graceful degradation — no filtering applied if module is missing
    def _filter_real_tasks(tasks, **_):  # type: ignore[misc]
        return tasks

router = APIRouter(prefix="/plan", tags=["planner"])


# Pydantic Models

class TaskInput(BaseModel):
    """Input task for plan generation"""
    id: str
    title: str
    courseName: Optional[str] = ""
    deadline: Optional[str] = None
    estimatedMinutes: Optional[int] = 120
    priority: Optional[str] = "medium"
    status: Optional[str] = "pending"
    description: Optional[str] = None
    assignedGrade: Optional[float] = None
    maxPoints: Optional[int] = None
    source: Optional[str] = "unknown"
    itemType: Optional[str] = "unknown"
    isActionableForAI: Optional[bool] = None
    isGradeRelated: Optional[bool] = None
    isDashboardOnly: Optional[bool] = None
    classificationConfidence: Optional[float] = None
    classificationReason: Optional[str] = None
    classroomWorkType: Optional[str] = None
    classroomSubmissionState: Optional[str] = None
    classroomLate: Optional[bool] = False
    hasRealDeadline: Optional[bool] = True
    deadlineSource: Optional[str] = None


class PlanRequest(BaseModel):
    studentName: str = "Student"
    tasks: List[TaskInput]


class PlanItem(BaseModel):
    taskId: Optional[str] = None
    taskTitle: str
    courseName: Optional[str] = ""
    deadline: Optional[str] = None
    status: Optional[str] = None
    suggestedDate: str
    suggestedTime: str
    hoursNeeded: float
    priority: str
    tip: str


class PlanResponse(BaseModel):
    success: bool
    studentName: Optional[str] = None
    generatedAt: Optional[str] = None
    items: Optional[List[PlanItem]] = None
    summary: Optional[str] = None
    error: Optional[str] = None

 # ranking the tasks 

_PRIORITY_RANK = {"urgent": 0, "high": 1, "medium": 2, "low": 3}
_MAX_PLANNER_TASKS = 30


def _parse_deadline(deadline: Optional[str]) -> Optional[datetime]:
    if not deadline:
        return None
    try:
        parsed = datetime.fromisoformat(deadline.replace("Z", "+00:00"))
        if parsed.tzinfo is not None:
            return parsed.replace(tzinfo=None)
        return parsed
    except Exception:
        return None


def _effective_priority(t: TaskInput, now: Optional[datetime] = None) -> str:
    """Priority from upcoming deadline — overdue/missed work stays low."""
    now = now or datetime.now()
    status = (t.status or "pending").lower()
    current = (t.priority or "medium").lower()

    if status in {"missed", "overdue"}:
        return "low"

    dl = _parse_deadline(t.deadline)
    if dl is None or t.hasRealDeadline is False:
        return "low"

    hours_left = (dl - now).total_seconds() / 3600
    if hours_left < 0:
        return "low"
    if hours_left <= 24:
        return "urgent"
    if hours_left <= 72:
        return "high" if _PRIORITY_RANK.get(current, 2) > 1 else current
    if hours_left <= 7 * 24:
        return "medium" if _PRIORITY_RANK.get(current, 2) > 2 else current

    return current if current in _PRIORITY_RANK else "medium"


def _fallback_plan_item(task: TaskInput, index: int, now: Optional[datetime] = None) -> PlanItem:
    """Create a deterministic slot when the LLM omits a validated task."""
    now = now or datetime.now()
    priority = _effective_priority(task, now)
    hours = max((task.estimatedMinutes or 60) / 60.0, 0.5)
    day_offset = index // 3
    start_hour = [9, 13, 17][index % 3]
    end_hour = min(start_hour + max(1, round(hours)), 21)

    return PlanItem(
        taskId=task.id,
        taskTitle=task.title,
        courseName=task.courseName or "",
        deadline=task.deadline if task.hasRealDeadline is not False else None,
        status=task.status or "pending",
        suggestedDate=(now + timedelta(days=day_offset)).strftime("%Y-%m-%d"),
        suggestedTime=f"{start_hour:02d}:00 - {end_hour:02d}:00",
        hoursNeeded=round(hours, 1),
        priority=priority,
        tip=(
            "Past deadline — catch up when you can, but focus on what's due next."
            if (task.status or "").lower() in {"missed", "overdue"}
            or (
                _parse_deadline(task.deadline) is not None
                and (_parse_deadline(task.deadline) - now).total_seconds() < 0
            )
            else "No hard deadline is available; schedule a short checkpoint so it does not drift."
        ),
    )


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
        dl = _parse_deadline(t.deadline) if t.hasRealDeadline is not False else None
        if dl:
            days_left = f"{(dl - now).days} days"

        priority_tag = f"[{_effective_priority(t, now).upper()}]"
        grade_info = ""
        if t.assignedGrade is not None and t.maxPoints is not None:
            grade_info = f" | Grade: {t.assignedGrade}/{t.maxPoints}"
        elif t.assignedGrade is not None:
            grade_info = f" | Grade: {t.assignedGrade}"

        lines.append(
            f"- {priority_tag} {t.title} | Course: {t.courseName or 'N/A'} "
            f"| Deadline: {t.deadline if t.hasRealDeadline is not False else 'none'} ({days_left} left) "
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



@router.post("/generate", response_model=PlanResponse)
async def generate_plan(req: PlanRequest):
    """
    Generate a personalized study plan from the student's tasks
    using Llama 3.3 via Groq API.
    """
    if not groq_client:
        raise HTTPException(status_code=503, detail="Planner service is not available")

    # Server-side safety guard: remove grades, summaries, completed work,
    # materials, dashboard-only rows, and any item not schedulable for AI.
    active_tasks = _filter_real_tasks(req.tasks)

    if not active_tasks:
        raise HTTPException(status_code=400, detail="No active tasks to plan for")

    # Sort by priority rank then deadline (soonest first)
    def sort_key(t):
        rank = _PRIORITY_RANK.get(_effective_priority(t), 2)
        dl = t.deadline or "9999-12-31"
        return (rank, dl)

    active_tasks.sort(key=sort_key)

    # Keep enough real work for a complete plan while protecting the LLM context.
    active_tasks = active_tasks[:_MAX_PLANNER_TASKS]
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

        priority_by_title = {
            (task.title or "").strip().lower(): _effective_priority(task)
            for task in active_tasks
        }

        items = [
            PlanItem(
                taskId=next(
                    (
                        task.id
                        for task in active_tasks
                        if (task.title or "").strip().lower()
                        == str(item.get("taskTitle", "")).strip().lower()
                    ),
                    None,
                ),
                taskTitle=item.get("taskTitle", ""),
                courseName=item.get("courseName", ""),
                deadline=next(
                    (
                        task.deadline
                        for task in active_tasks
                        if (task.title or "").strip().lower()
                        == str(item.get("taskTitle", "")).strip().lower()
                        and task.hasRealDeadline is not False
                    ),
                    None,
                ),
                status=next(
                    (
                        task.status
                        for task in active_tasks
                        if (task.title or "").strip().lower()
                        == str(item.get("taskTitle", "")).strip().lower()
                    ),
                    None,
                ),
                suggestedDate=item.get("suggestedDate", ""),
                suggestedTime=item.get("suggestedTime", ""),
                hoursNeeded=float(item.get("hoursNeeded", 1)),
                priority=priority_by_title.get(
                    str(item.get("taskTitle", "")).strip().lower(),
                    item.get("priority", "medium"),
                ),
                tip=item.get("tip", ""),
            )
            for item in parsed.get("items", [])
        ]

        planned_titles = {
            (item.taskTitle or "").strip().lower()
            for item in items
            if (item.taskTitle or "").strip()
        }
        for task in active_tasks:
            key = (task.title or "").strip().lower()
            if key not in planned_titles:
                items.append(_fallback_plan_item(task, len(items), datetime.now()))
                planned_titles.add(key)

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
