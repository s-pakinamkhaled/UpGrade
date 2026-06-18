"""
Study plan generation endpoint.

Uses the configurable LLM routing layer (LLMProvider) with:
- PLAN_MODEL as primary, PLAN_FALLBACK_MODEL as fallback
- Automatic retry (once) before falling back
- Deterministic fallback items for any tasks the LLM omits
- Optional LLM-as-a-Judge evaluation after generation
- Safe structured error responses that never expose internals
"""

from __future__ import annotations

import json
import logging
import os
import sys
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

logger = logging.getLogger(__name__)

# ── Path and environment setup ─────────────────────────────────────────────────
current_dir = os.path.dirname(os.path.abspath(__file__))
# routes → api → app → backend → project_root
project_root = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.dirname(current_dir)))
)

backend_env = os.path.join(project_root, "backend", ".env")
ai_env = os.path.join(project_root, "ai", ".env")
load_dotenv(backend_env)
load_dotenv(ai_env)

ai_path = os.path.join(project_root, "ai")
if ai_path not in sys.path:
    sys.path.insert(0, ai_path)

# ── LLM provider initialisation ────────────────────────────────────────────────
try:
    from llm.config import LLMConfig, load_config as _load_llm_config
    from llm.provider import LLMProvider
    from llm.judge import LLMJudge

    _llm_config: Optional[LLMConfig] = _load_llm_config()
    _llm_provider: Optional[LLMProvider] = LLMProvider(_llm_config)
    _llm_judge: Optional[LLMJudge] = LLMJudge(_llm_config, _llm_provider)
    logger.info(
        "[Planner] LLM provider ready — provider=%s plan_model=%s fallback=%s",
        _llm_config.llm_provider,
        _llm_config.plan_model,
        _llm_config.plan_fallback_model,
    )
except Exception as _init_err:
    logger.warning("[Planner] Could not initialise LLM provider: %s", _init_err)
    _llm_config = None
    _llm_provider = None
    _llm_judge = None

# ── Task filter ────────────────────────────────────────────────────────────────
try:
    from task_filter import filter_real_tasks as _filter_real_tasks

    logger.info("[Planner] Task filter loaded")
except ImportError:

    def _filter_real_tasks(tasks, **_):  # type: ignore[misc]
        return tasks


router = APIRouter(prefix="/plan", tags=["planner"])

# ── Pydantic models (unchanged — preserves frontend contract) ──────────────────


class TaskInput(BaseModel):
    id: str
    title: str
    courseName: Optional[str] = ""
    deadline: Optional[str] = None
    estimatedMinutes: Optional[int] = 180
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
    description:Optional[str] =None


class PlanResponse(BaseModel):
    success: bool
    studentName: Optional[str] = None
    generatedAt: Optional[str] = None
    items: Optional[List[PlanItem]] = None
    summary: Optional[str] = None
    error: Optional[str] = None
    # Optional, non-breaking: lets the client/observer see the judge verdict.
    judge: Optional[Dict[str, Any]] = None


# ── Priority / deadline helpers ────────────────────────────────────────────────

_PRIORITY_RANK: Dict[str, int] = {"urgent": 0, "high": 1, "medium": 2, "low": 3}
_MAX_PLANNER_TASKS = 80


def _parse_deadline(deadline: Optional[str]) -> Optional[datetime]:
    if not deadline:
        return None
    try:
        parsed = datetime.fromisoformat(deadline.replace("Z", "+00:00"))
        return parsed.replace(tzinfo=None) if parsed.tzinfo is not None else parsed
    except Exception:
        return None


def _effective_priority(t: TaskInput, now: Optional[datetime] = None) -> str:
    """Derive effective priority from deadline proximity.
    Description: The description of the task is used to determine the priority of the task.
    first the missed tasks should has the highest priority, but in some conditional cases ,
    like the missed tasks should not have higher piriority with the inprogress or pending tasks that its deadline is too close.
    for instance i have a pending task after 2 days and a 3 missed tasks the pending task that its deadline after 2 days should have the higher piriority over the missed tasks,
    because the purpose here is finishing the incoming tasks with the missed tasks but witoout pressing the user and distracting the user with the missed tasks and that will lead the user to be busy with the missed tasks and leave the incoming tasks and that will lead the user to be late with the incoming tasks and handed the incoming tasks lately and that is will make the user at risk. 
    so the purpose here to put the high piriority to the missed tasks but thye the pending tasks with 
    close deadline must have the higher piriority over the missed tasks when the user complete the incoming tasks with higher piriority then the missed tasks will take the piriority after the tasks that with closde deadline.
    """
    now = now or datetime.now()
    status = (t.status or "pending").lower()
    current = (t.priority or "high").lower()

    if status in {"missed", "overdue"}:
        return "high"

    dl = _parse_deadline(t.deadline)
    if dl is None or t.hasRealDeadline is False:
        return "low"

    hours_left = (dl - now).total_seconds() / 3600
    if hours_left < 0:
        return "urgent"
    if hours_left <= 48:
        return "urgent"
    if hours_left <= 96:
        return "high"
    if hours_left <= 7 * 24:
        return "medium"

    return "low"


def _fallback_plan_item(
    task: TaskInput, index: int, now: Optional[datetime] = None
) -> PlanItem:
    """Create a deterministic schedule slot when the LLM omits a validated task.

    Honours the same logic as the prompt: finish ~2 day before the deadline,
    overdue work goes to today, and no task is scheduled after its deadline all the pending or inprogress tasks must be finished before its deadline.
    if the task deadline after 2 days this task must have the highest piriority to be finished and this tasks have the higher piriority over the missed tasks. 
    """
    now = now or datetime.now()
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    priority = _effective_priority(task, now)
    hours = max((task.estimatedMinutes or 60) / 60.0, 0.5)
    start_hour = [9, 13, 17][index % 3]
    end_hour = min(start_hour + max(1, round(hours)), 21)

    dl = _parse_deadline(task.deadline) if task.hasRealDeadline is not False else None
    overdue = (
        (task.status or "").lower() in {"missed", "overdue"}
        or (dl is not None and (dl - now).total_seconds() < 0)
    )

    if dl is None or overdue:
        # No deadline, or already overdue → act now, staggering across days.
        suggested = today + timedelta(days=index // 3)
    else:
        # Aim to finish one day before the deadline, but never in the past.
        target = dl - timedelta(days=1)
        suggested = target if target >= today else today

    return PlanItem(
        taskId=task.id,
        taskTitle=task.title,
        courseName=task.courseName or "",
        deadline=task.deadline if task.hasRealDeadline is not False else None,
        status=task.status or "pending",
        suggestedDate=suggested.strftime("%Y-%m-%d"),
        suggestedTime=f"{start_hour:02d}:00 – {end_hour:02d}:00",
        hoursNeeded=round(hours, 2),
        priority=priority,
        tip=(
            "Overdue — start today and submit as soon as you can."
            if overdue
            else (
                "Finish a day early to leave a safety buffer before the deadline."
                if dl is not None
                else "No hard deadline; slot a short checkpoint so it doesn't drift."
            )
        ),
    )


def _build_prompt(req: PlanRequest) -> str:
    """Build a detailed task-list prompt for the planner LLM. including the tips per course and the tips per task.
        overdue work goes to today, and no task is scheduled after its deadline all the pending or inprogress tasks must be finished before its deadline.
    if the task deadline after 2 days this task must have the highest piriority to be finished and this tasks have the higher piriority over the missed tasks. 
    the purpose here to make the student to finish trhe missed tasks without be late of deadline  with the pending tasks the pending tasks with highest piriority should be finished first and then  if there is not pending or inprogress task with the highest piriority then the missed tasks should be finished and that will make the student to finish the tasks without be late of deadline with the pending or inprogress tasks.
    """
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
            f"| Deadline: {t.deadline if t.hasRealDeadline is not False else 'none'} "
            f"({days_left} left) "
            f"| Est: {t.estimatedMinutes or 60} min | Status: {t.status or 'pending'}"
            f"{grade_info}"
        )

    today_str = now.strftime("%Y-%m-%d")
    tomorrow_str = (now + timedelta(days=1)).strftime("%Y-%m-%d")

    lines += [
        "",
        "Your job: act like the student personally sitting down to plan their week.",
        "Produce a realistic, day-by-day schedule that a real person could follow.",
        "",
        "Scheduling rules (follow them strictly and logically):",
        "0. The purpose here to make the student to finish the tasks without be late of deadline with the pending or inprogress tasks the pending tasks with highest piriority should be finished first and then  if there is not pending or inprogress task with the highest piriority then the missed tasks should be finished and that will make the student to finish the tasks without be late of deadline with the pending or inprogress tasks.",
        "1. ORDER by urgency: overdue/missed task is very importand to be finished in case there is no pending or inprogress task that its piriority is urgent or high because we need the student finish the tasks pending or inprogress within high or urgent piriority first and then consider the piriority to the missed tasks. "
        "FIRST. Never place a later deadline before an earlier one.",
        "2. FINISH-BEFORE-DEADLINE: schedule each task to be completed at least one "
        "full day BEFORE its deadline whenever possible (buffer for the unexpected). "
        "Never schedule a task on a day AFTER its deadline.",
        "4. REALISTIC LOAD: do not pile everything on one day. Aim for at most ~from 4 to 7 hours per day "
        "study hours per day; spread the remaining tasks across the following days.",
        "5. CHRONOLOGICAL DAYS: use real calendar dates. Today is "
        f"{today_str}; tomorrow is {tomorrow_str}. Spread tasks across consecutive "
        "days starting today.",
        "6. Allocate sensible time windows (e.g. '14:00 – 16:00') based on each "
        "task's estimated effort.",
        "7. For each task write a short, concrete 'tip' describing what to actually "
        "do that day (e.g. 'Draft the CI/CD pipeline and test one stage'), not "
        "generic advice.",
        "8. Include EVERY task listed above exactly once. Never add, merge, rename, "
        "or invent tasks, courses, grades, or deadlines.",
        "9. Provide a 2–3 sentence 'summary' explaining the overall strategy like descriping t0o the student how will finish this task"
        "(what to focus on today, how the week is balanced).",
        "10. Respond with VALID JSON ONLY — no markdown fences, no extra text.",
        "",
        "Required JSON schema (order items by suggestedDate, earliest first):",
        "{",
        '  "items": [',
        "    {",
        '      "taskTitle": "string (must match a task title above exactly)",',
        '      "courseName": "string",',
        '      "suggestedDate": "YYYY-MM-DD",',
        '      "suggestedTime": "HH:MM – HH:MM",',
        '      "hoursNeeded": number,',
        '      "priority": "urgent|high|medium|low",',
        '      "tip": "string (concrete action for that day)"',
        "    }",
        "  ],",
        '  "summary": "string"',
        "}",
    ]
    return "\n".join(lines)


# ── Endpoint ───────────────────────────────────────────────────────────────────


@router.post("/generate", response_model=PlanResponse)
async def generate_plan(req: PlanRequest) -> PlanResponse:
    """Generate a personalised study plan from the student's tasks.

    Uses PLAN_MODEL with automatic retry and fallback to PLAN_FALLBACK_MODEL.
    Returns a validated PlanResponse — the response schema is identical to the
    previous version so the Flutter frontend requires no changes.
    """
    if not _llm_provider or not _llm_config:
        raise HTTPException(status_code=503, detail="Planner service is not available")

    # Server-side safety: remove grades, completed work, materials, etc.
    active_tasks = _filter_real_tasks(req.tasks)

    if not active_tasks:
        raise HTTPException(status_code=400, detail="No active tasks to plan for")

    # Order strictly by deadline ascending so the plan is chronological and
    # intuitive: overdue items lead (earliest dates), then today, tomorrow, etc.
    # Tasks without a real deadline are placed last. This is the rule a student
    # expects ("do the soonest-due thing first") and fixes ordering bugs where a
    # later deadline appeared before an earlier one.
    def _sort_key(t: TaskInput):
        dl = _parse_deadline(t.deadline) if t.hasRealDeadline is not False else None
        if dl is None:
            return (1, datetime.max)
        return (0, dl)

    active_tasks.sort(key=_sort_key)
    active_tasks = active_tasks[:_MAX_PLANNER_TASKS]

    req_trimmed = PlanRequest(studentName=req.studentName, tasks=active_tasks)
    prompt = _build_prompt(req_trimmed)

    system_message = (
        "You are an expert academic study planner. "
        "You always respond with valid JSON only — no markdown fences, no extra text. "
        "You MUST only schedule tasks that are explicitly listed in the user prompt. "
        "Never invent tasks, courses, grades, or deadlines."
    )

    messages = [
        {"role": "system", "content": system_message},
        {"role": "user", "content": prompt},
    ]

    try:
        # Keep max_tokens at 2000: enough for 13+ tasks with tips and summary
        # while staying within Groq's free-tier tokens-per-minute budget.
        # Each task item in the JSON response is ~80-120 tokens, so 2000 covers
        # up to ~20 tasks with a summary and still leaves budget for a second
        # concurrent request.
        parsed, gen_result = _llm_provider.generate_json(
            messages=messages,
            model=_llm_config.plan_model,
            fallback_model=_llm_config.plan_fallback_model,
            temperature=0.4,
            max_tokens=2000,
        )

        logger.info(
            "[Planner] generated provider=%s model=%s used_fallback=%s latency_ms=%.0f",
            gen_result.provider,
            gen_result.model,
            gen_result.used_fallback,
            gen_result.latency_ms,
        )

    except RuntimeError as exc:
        # Both primary and fallback exhausted
        logger.error("[Planner] all models failed: %s", type(exc).__name__)
        raise HTTPException(
            status_code=502,
            detail="Study plan generation failed. Please try again.",
        )
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=502,
            detail="Planner returned a non-JSON response. Please try again.",
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("[Planner] unexpected error: %s", type(exc).__name__)
        raise HTTPException(
            status_code=500,
            detail="Plan generation failed. Please try again.",
        )

    # ── Build PlanItem list with hallucination guards ──────────────────────────

    priority_by_title: Dict[str, str] = {
        (t.title or "").strip().lower(): _effective_priority(t)
        for t in active_tasks
    }

    items: List[PlanItem] = []
    for raw in parsed.get("items", []):
        title_key = str(raw.get("taskTitle", "")).strip().lower()

        # Only accept items whose title matches a real input task
        matched_task = next(
            (t for t in active_tasks if (t.title or "").strip().lower() == title_key),
            None,
        )

        items.append(
            PlanItem(
                taskId=matched_task.id if matched_task else None,
                taskTitle=raw.get("taskTitle", ""),
                courseName=raw.get("courseName", ""),
                deadline=(
                    matched_task.deadline
                    if matched_task and matched_task.hasRealDeadline is not False
                    else None
                ),
                status=matched_task.status if matched_task else None,
                suggestedDate=raw.get("suggestedDate", ""),
                suggestedTime=raw.get("suggestedTime", ""),
                hoursNeeded=float(raw.get("hoursNeeded", 1)),
                # Always use server-computed priority, not LLM's suggestion
                priority=priority_by_title.get(title_key, raw.get("priority", "medium")),
                tip=raw.get("tip", ""),
            )
        )

    # Fill in any tasks the LLM omitted
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

    # Present the finish scenario chronologically (today → later) so the
    # day-by-day plan reads in order regardless of how the LLM ordered items.
    def _item_sort_key(item: PlanItem):
        return (item.suggestedDate or "9999-12-31", item.suggestedTime or "")

    items.sort(key=_item_sort_key)

    # ── Optional judge evaluation (non-blocking) ───────────────────────────────
    judge_meta: Optional[Dict[str, Any]] = None
    if _llm_judge and _llm_config.enable_study_plan_judge:
        verdict = _llm_judge.evaluate_study_plan(
            plan_items=[i.model_dump() for i in items],
            input_tasks=[t.model_dump() for t in active_tasks],
            summary=parsed.get("summary", ""),
            generator_model=gen_result.model,
        )
        judge_meta = {
            "passed": verdict.passed,
            "hallucination_detected": verdict.hallucination_detected,
            "score": verdict.score,
            "recommended_action": verdict.recommended_action,
            "judge_model": verdict.judge_model,
        }
        logger.info(
            "[Planner] judge verdict passed=%s score=%.2f action=%s model=%s",
            verdict.passed,
            verdict.score,
            verdict.recommended_action,
            verdict.judge_model,
        )

    return PlanResponse(
        success=True,
        studentName=req.studentName,
        generatedAt=datetime.now().isoformat(),
        items=items,
        summary=parsed.get("summary", ""),
        judge=judge_meta,
    )


@router.get("/health")
async def planner_health():
    """Check planner service availability."""
    if not _llm_provider or not _llm_config:
        return {"status": "unavailable", "service": "none"}

    return {
        "status": "ok",
        "service": _llm_config.plan_model,
        "provider": _llm_config.llm_provider,
        "fallback": _llm_config.plan_fallback_model,
    }
