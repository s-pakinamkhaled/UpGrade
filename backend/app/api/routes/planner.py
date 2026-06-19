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
from typing import Any, Dict, List, Optional, Tuple

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


class DayBudget(BaseModel):
    """A user-customized study-hour budget for a specific calendar day."""

    date: str  # YYYY-MM-DD
    hours: float


class PlanRequest(BaseModel):
    studentName: str = "Student"
    tasks: List[TaskInput]
    # How many hours per day the student wants to study by default. Used to
    # spread tasks realistically instead of piling everything on one day.
    defaultDailyHours: Optional[float] = None
    # Per-day overrides, e.g. "today I can do 5h, tomorrow only 3h". These take
    # precedence over defaultDailyHours for the matching date.
    dailyHours: Optional[List[DayBudget]] = None


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
    # True when the plan was generated locally (LLM unavailable/rate-limited).
    degraded: Optional[bool] = None


# ── Priority / deadline helpers ────────────────────────────────────────────────

_PRIORITY_RANK: Dict[str, int] = {"urgent": 0, "high": 1, "medium": 2, "low": 3}
_MAX_PLANNER_TASKS = 80
# Fallback daily study capacity (hours) when the user has not customized it.
_DEFAULT_DAILY_HOURS = 4.0


def _resolve_daily_capacity(req: PlanRequest) -> Tuple[float, Dict[str, float]]:
    """Return (default hours/day, {date: hours}) from the request.

    Both are user-customizable. The per-date map lets a student say e.g.
    "today I'll study 5h, tomorrow only 3h"; the default applies to any day
    without an explicit override.
    """
    default_hours = req.defaultDailyHours or _DEFAULT_DAILY_HOURS
    # Guard against nonsensical values.
    default_hours = min(max(default_hours, 0.5), 16.0)

    overrides: Dict[str, float] = {}
    for budget in req.dailyHours or []:
        if not budget.date:
            continue
        overrides[budget.date] = min(max(budget.hours, 0.0), 16.0)
    return default_hours, overrides


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
        tip=_fallback_tip(task, overdue=overdue, has_deadline=dl is not None),
    )


def _fallback_tip(task: TaskInput, *, overdue: bool, has_deadline: bool) -> str:
    """Task-specific tip used only when the LLM is unavailable (offline/rate-limited).

    Derived from the task's own title and deadline proximity to read like real
    advice rather than a generic placeholder. The LLM writes richer tips in
    the normal path; this is the graceful-degradation fallback.
    """
    title = (task.title or "this task").strip()
    short = title if len(title) <= 50 else f"{title[:47]}…"
    course = (task.courseName or "").strip()
    course_hint = f" for {course}" if course else ""

    if overdue:
        return (
            f"This task is overdue — open {short} now, complete what you can, "
            f"and submit immediately to limit the late penalty{course_hint}."
        )
    if has_deadline:
        return (
            f"Work through {short}{course_hint} in a focused session today "
            f"so you finish at least one day before the deadline and have "
            f"time to review your work."
        )
    return (
        f"Block a dedicated study slot for {short}{course_hint}; "
        f"break the work into smaller steps and aim to complete the first "
        f"milestone in this session."
    )


def _build_deterministic_plan(
    active_tasks: List[TaskInput],
    now: Optional[datetime] = None,
    default_daily_hours: float = _DEFAULT_DAILY_HOURS,
    daily_overrides: Optional[Dict[str, float]] = None,
) -> Tuple[List[PlanItem], str]:
    """Build a complete study plan WITHOUT the LLM.

    Used as a graceful fallback when the LLM provider is unavailable or
    rate-limited, so the student always receives a usable, logical schedule
    instead of an error. The schedule honours the same rules as the prompt:
    deadline-ordered, finish ~1 day early, overdue work first — and now it
    also respects the student's daily study capacity (default + per-day
    overrides) so work is spread realistically instead of piling up.
    """
    now = now or datetime.now()
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    daily_overrides = daily_overrides or {}

    def capacity_for(day: datetime) -> float:
        return daily_overrides.get(day.strftime("%Y-%m-%d"), default_daily_hours)

    # Tasks arrive deadline-sorted from the caller; keep that order so earlier
    # deadlines are scheduled first.
    used_hours: Dict[str, float] = {}
    items: List[PlanItem] = []

    for task in active_tasks:
        hours = max((task.estimatedMinutes or 60) / 60.0, 0.5)
        dl = (
            _parse_deadline(task.deadline)
            if task.hasRealDeadline is not False
            else None
        )
        overdue = (task.status or "").lower() in {"missed", "overdue"} or (
            dl is not None and (dl - now).total_seconds() < 0
        )

        # Window in which the task may be scheduled.
        if dl is None or overdue:
            target = today + timedelta(days=14)  # flexible: spread over 2 weeks
        else:
            target = max(dl - timedelta(days=1), today)

        # Find the earliest day from today→target that still has spare capacity.
        chosen = target
        day = today
        while day <= target:
            key = day.strftime("%Y-%m-%d")
            already = used_hours.get(key, 0.0)
            if already == 0.0 or already + hours <= capacity_for(day):
                chosen = day
                break
            day += timedelta(days=1)

        key = chosen.strftime("%Y-%m-%d")
        start_hour = int(9 + used_hours.get(key, 0.0))
        start_hour = min(start_hour, 20)
        end_hour = min(start_hour + max(1, round(hours)), 22)
        used_hours[key] = used_hours.get(key, 0.0) + hours

        items.append(
            PlanItem(
                taskId=task.id,
                taskTitle=task.title,
                courseName=task.courseName or "",
                deadline=task.deadline if task.hasRealDeadline is not False else None,
                status=task.status or "pending",
                suggestedDate=key,
                suggestedTime=f"{start_hour:02d}:00 – {end_hour:02d}:00",
                hoursNeeded=round(hours, 2),
                priority=_effective_priority(task, now),
                tip=_fallback_tip(task, overdue=overdue, has_deadline=dl is not None),
            )
        )

    items.sort(
        key=lambda it: (it.suggestedDate or "9999-12-31", it.suggestedTime or "")
    )

    today_str = now.strftime("%Y-%m-%d")
    due_today = sum(1 for it in items if it.suggestedDate == today_str)
    overdue = sum(
        1 for it in items if (it.status or "").lower() in {"missed", "overdue"}
    )

    parts = [
        f"Here is a deadline-ordered plan for your {len(items)} task"
        f"{'s' if len(items) != 1 else ''}, kept within about "
        f"{default_daily_hours:g}h of study per day."
    ]
    if due_today:
        parts.append(
            f"Start with the {due_today} item{'s' if due_today != 1 else ''} "
            f"scheduled for today."
        )
    if overdue:
        parts.append(
            f"You have {overdue} overdue item{'s' if overdue != 1 else ''} — "
            f"tackle those first to catch up."
        )
    parts.append(
        "Each task is scheduled to finish a day before its deadline so you keep "
        "a safety buffer."
    )
    summary = " ".join(parts)
    return items, summary


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

    # User-customized study capacity. The student can set a default and override
    # specific days ("today 5h, tomorrow 3h"); honour these limits exactly.
    default_hours, overrides = _resolve_daily_capacity(req)
    capacity_lines = [
        "",
        "Student's study capacity (HARD LIMITS — never exceed on any day):",
        f"- Default: about {default_hours:g} hours of study per day.",
    ]
    if overrides:
        for date_key in sorted(overrides):
            capacity_lines.append(
                f"- On {date_key}: at most {overrides[date_key]:g} hours."
            )
    capacity_lines.append(
        "Each task's required time is given as 'Est:' below — treat it as the "
        "hours the student expects to spend, and pack days up to (but not over) "
        "the capacity above. If everything does not fit, push lower-priority "
        "tasks to later days while still finishing before each deadline."
    )
    lines += capacity_lines

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
        "4. REALISTIC LOAD: respect the student's daily study capacity stated "
        "above. Do not exceed a day's hour limit; spread remaining tasks across "
        "the following days. Sum each day's hoursNeeded so it stays within limit.",
        "5. CHRONOLOGICAL DAYS: use real calendar dates. Today is "
        f"{today_str}; tomorrow is {tomorrow_str}. Spread tasks across consecutive "
        "days starting today.",
        "6. Allocate sensible time windows (e.g. '14:00 – 16:00') whose length "
        "matches each task's expected hours ('Est:' value).",
        "7. For each task write ONE specific 'tip' (1–2 sentences, 20–35 words) that "
        "describes the concrete study approach for THIS particular assignment — name "
        "the exact topic, concept, or deliverable the student should work on "
        "(e.g. 'Start by sketching the ER diagram with all entities and foreign-key "
        "relationships, then write the CREATE TABLE statements — aim to finish both "
        "in this session'). Never use generic filler like 'work hard', 'stay focused', "
        "'review material', or 'make sure to complete it'.",
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

    req_trimmed = PlanRequest(
        studentName=req.studentName,
        tasks=active_tasks,
        defaultDailyHours=req.defaultDailyHours,
        dailyHours=req.dailyHours,
    )
    prompt = _build_prompt(req_trimmed)
    default_hours, daily_overrides = _resolve_daily_capacity(req)

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
        # max_tokens=3000: each task item with a richer tip is ~120-150 tokens,
        # so 3000 covers ~20-25 tasks with AI-written tips. Tasks beyond that are
        # filled in by the deterministic fallback which still produces a complete
        # schedule. Increasing from 1500 ensures the LLM generates meaningful,
        # specific tips rather than truncating mid-plan.
        parsed, gen_result = _llm_provider.generate_json(
            messages=messages,
            model=_llm_config.plan_model,
            fallback_model=_llm_config.plan_fallback_model,
            temperature=0.4,
            max_tokens=3000,
        )

        logger.info(
            "[Planner] generated provider=%s model=%s used_fallback=%s latency_ms=%.0f",
            gen_result.provider,
            gen_result.model,
            gen_result.used_fallback,
            gen_result.latency_ms,
        )

    except (RuntimeError, json.JSONDecodeError, Exception) as exc:
        # The LLM is unavailable / rate-limited / returned bad JSON. Rather than
        # failing the request (502/500), gracefully degrade to a locally
        # generated, deadline-ordered plan so the student always gets a usable
        # schedule. HTTPException is re-raised so explicit 400/503 still surface.
        if isinstance(exc, HTTPException):
            raise
        logger.warning(
            "[Planner] LLM unavailable (%s) — returning deterministic plan",
            type(exc).__name__,
        )
        items, summary = _build_deterministic_plan(
            active_tasks,
            datetime.now(),
            default_daily_hours=default_hours,
            daily_overrides=daily_overrides,
        )
        return PlanResponse(
            success=True,
            studentName=req.studentName,
            generatedAt=datetime.now().isoformat(),
            items=items,
            summary=summary,
            degraded=True,
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
