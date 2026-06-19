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
        _llm_config.plan_provider,
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
# A small overload is acceptable for indivisible tasks, but the planner should
# never freely pile work far beyond the student's configured daily intention.
_DAILY_CAPACITY_TOLERANCE_HOURS = 1.0
_PLANNING_HORIZON_DAYS = 14


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


def _task_estimated_hours(task: TaskInput) -> float:
    """Return the task estimate in hours, using the task as source of truth."""
    minutes = task.estimatedMinutes or 60
    return round(max(minutes / 60.0, 0.5), 2)


def _day_start(value: datetime) -> datetime:
    return value.replace(hour=0, minute=0, second=0, microsecond=0)


def _deadline_minutes_for_date(task: TaskInput, date_key: str) -> Optional[int]:
    dl = _parse_deadline(task.deadline) if task.hasRealDeadline is not False else None
    if dl is None or dl.strftime("%Y-%m-%d") != date_key:
        return None
    return dl.hour * 60 + dl.minute


def _format_study_window(
    used_before_hours: float,
    hours: float,
    latest_end_minutes: Optional[int] = None,
) -> str:
    """Create a readable time block whose length matches the estimate."""
    duration_minutes = max(30, int(round(hours * 60)))
    start_minutes = (9 * 60) + int(round(used_before_hours * 60))
    end_minutes = start_minutes + duration_minutes

    # Keep very large days displayable. Normal study budgets fit without this.
    latest_end = latest_end_minutes if latest_end_minutes is not None else 23 * 60
    if end_minutes > latest_end:
        end_minutes = latest_end
        start_minutes = max(0, end_minutes - duration_minutes)

    start_hour, start_minute = divmod(start_minutes, 60)
    end_hour, end_minute = divmod(end_minutes, 60)
    return f"{start_hour:02d}:{start_minute:02d} - {end_hour:02d}:{end_minute:02d}"


def _capacity_for_date(
    date_key: str,
    default_daily_hours: float,
    daily_overrides: Dict[str, float],
) -> float:
    return daily_overrides.get(date_key, default_daily_hours)


def _allowed_load_for_capacity(capacity: float) -> float:
    if capacity <= 0:
        return 0.0
    return capacity + _DAILY_CAPACITY_TOLERANCE_HOURS


def _is_missed_or_overdue(task: TaskInput, now: datetime) -> bool:
    dl = _parse_deadline(task.deadline) if task.hasRealDeadline is not False else None
    return (task.status or "").lower() in {"missed", "overdue"} or (
        dl is not None and (dl - now).total_seconds() < 0
    )


def _planning_sort_key(task: TaskInput, now: Optional[datetime] = None):
    """Order work by risk, not by old deadlines alone.

    Upcoming urgent/high work is scheduled before missed catch-up work so the
    planner does not create a new missed deadline while clearing old backlog.
    """
    now = now or datetime.now()
    dl = _parse_deadline(task.deadline) if task.hasRealDeadline is not False else None
    priority = _effective_priority(task, now)
    priority_rank = _PRIORITY_RANK.get(priority, 9)
    missed_or_overdue = _is_missed_or_overdue(task, now)

    if not missed_or_overdue and priority == "urgent":
        bucket = 0
    elif not missed_or_overdue and priority == "high":
        bucket = 1
    elif missed_or_overdue:
        bucket = 2
    elif priority == "medium":
        bucket = 3
    else:
        bucket = 4

    deadline_key = dl if dl is not None else datetime.max
    return (bucket, deadline_key, priority_rank, -_task_estimated_hours(task), task.title)


def _find_capacity_aware_day(
    task: TaskInput,
    hours: float,
    used_hours: Dict[str, float],
    now: datetime,
    default_daily_hours: float,
    daily_overrides: Dict[str, float],
) -> str:
    """Choose a date without exceeding the student's daily study budget.

    The search fills earlier days up to their capacity before pushing work
    forward. A single task longer than the daily budget is allowed by itself,
    because the current response schema represents each task as one plan item.
    """
    today = _day_start(now)
    dl = _parse_deadline(task.deadline) if task.hasRealDeadline is not False else None
    overdue = (task.status or "").lower() in {"missed", "overdue"} or (
        dl is not None and (dl - now).total_seconds() < 0
    )

    if dl is None or overdue:
        last_preferred_day = today + timedelta(days=_PLANNING_HORIZON_DAYS)
        deadline_day = last_preferred_day
    else:
        deadline_day = max(_day_start(dl), today)
        last_preferred_day = max(_day_start(dl - timedelta(days=1)), today)

    def fits(day: datetime) -> bool:
        key = day.strftime("%Y-%m-%d")
        capacity = _capacity_for_date(key, default_daily_hours, daily_overrides)
        allowed = _allowed_load_for_capacity(capacity)
        already = used_hours.get(key, 0.0)

        if allowed <= 0:
            return False
        if hours > allowed:
            return already == 0.0
        return already + hours <= allowed

    def first_fit(start_day: datetime, end_day: datetime) -> Optional[str]:
        day = start_day
        while day <= end_day:
            if fits(day):
                return day.strftime("%Y-%m-%d")
            day += timedelta(days=1)
        return None

    # Prefer the one-day-before-deadline buffer. If it is full, use the due day.
    found = first_fit(today, last_preferred_day)
    if found:
        return found

    if deadline_day > last_preferred_day:
        found = first_fit(last_preferred_day + timedelta(days=1), deadline_day)
        if found:
            return found

    if dl is not None and not overdue:
        # A real upcoming task must not be planned after its deadline. If the
        # capacity before the deadline is already full, choose the least-loaded
        # valid day and let the overload be visible instead of silently missing.
        candidate_days: List[datetime] = []
        day = today
        while day <= deadline_day:
            key = day.strftime("%Y-%m-%d")
            if _capacity_for_date(key, default_daily_hours, daily_overrides) > 0:
                candidate_days.append(day)
            day += timedelta(days=1)

        if not candidate_days:
            return deadline_day.strftime("%Y-%m-%d")

        chosen = min(
            candidate_days,
            key=lambda d: (
                used_hours.get(d.strftime("%Y-%m-%d"), 0.0)
                / max(
                    _capacity_for_date(
                        d.strftime("%Y-%m-%d"),
                        default_daily_hours,
                        daily_overrides,
                    ),
                    0.5,
                ),
                used_hours.get(d.strftime("%Y-%m-%d"), 0.0),
            ),
        )
        return chosen.strftime("%Y-%m-%d")

    found = first_fit(
        deadline_day + timedelta(days=1),
        deadline_day + timedelta(days=_PLANNING_HORIZON_DAYS),
    )
    if found:
        return found

    # Last resort: keep the item in the plan, even if every configured day is 0h.
    return deadline_day.strftime("%Y-%m-%d")


def _normalize_plan_items_to_capacity(
    raw_items: List[PlanItem],
    active_tasks: List[TaskInput],
    now: Optional[datetime] = None,
    default_daily_hours: float = _DEFAULT_DAILY_HOURS,
    daily_overrides: Optional[Dict[str, float]] = None,
) -> List[PlanItem]:
    """Make the LLM response obey task estimates and daily hour budgets."""
    now = now or datetime.now()
    daily_overrides = daily_overrides or {}
    raw_by_title = {
        (item.taskTitle or "").strip().lower(): item
        for item in raw_items
        if (item.taskTitle or "").strip()
    }
    raw_order_by_title = {
        (item.taskTitle or "").strip().lower(): index
        for index, item in enumerate(raw_items)
        if (item.taskTitle or "").strip()
    }

    def normalized_order(task: TaskInput):
        key = (task.title or "").strip().lower()
        base = _planning_sort_key(task, now)
        raw_rank = raw_order_by_title.get(key, len(raw_order_by_title))
        return (base[0], base[1], base[2], raw_rank, base[3], base[4])

    used_hours: Dict[str, float] = {}
    normalized: List[PlanItem] = []

    for task in sorted(active_tasks, key=normalized_order):
        key = (task.title or "").strip().lower()
        raw = raw_by_title.get(key)
        hours = _task_estimated_hours(task)
        suggested_date = _find_capacity_aware_day(
            task,
            hours,
            used_hours,
            now,
            default_daily_hours,
            daily_overrides,
        )
        used_before = used_hours.get(suggested_date, 0.0)
        used_hours[suggested_date] = used_before + hours

        dl = _parse_deadline(task.deadline) if task.hasRealDeadline is not False else None
        overdue = (task.status or "").lower() in {"missed", "overdue"} or (
            dl is not None and (dl - now).total_seconds() < 0
        )

        normalized.append(
            PlanItem(
                taskId=task.id,
                taskTitle=task.title,
                courseName=task.courseName or "",
                deadline=task.deadline if task.hasRealDeadline is not False else None,
                status=task.status or "pending",
                suggestedDate=suggested_date,
                suggestedTime=_format_study_window(
                    used_before,
                    hours,
                    _deadline_minutes_for_date(task, suggested_date),
                ),
                hoursNeeded=hours,
                priority=_effective_priority(task, now),
                tip=(
                    raw.tip.strip()
                    if raw and raw.tip and raw.tip.strip()
                    else _fallback_tip(task, overdue=overdue, has_deadline=dl is not None)
                ),
                description=raw.description if raw else None,
            )
        )

    normalized.sort(
        key=lambda it: (it.suggestedDate or "9999-12-31", it.suggestedTime or "")
    )
    return normalized


def _fill_missing_llm_tips(
    raw_items: List[PlanItem],
    active_tasks: List[TaskInput],
    system_message: str,
) -> List[PlanItem]:
    """Ask the LLM for concrete tips when the main response omitted any."""
    if not _llm_provider or not _llm_config:
        return raw_items

    raw_by_title = {
        (item.taskTitle or "").strip().lower(): item
        for item in raw_items
        if (item.taskTitle or "").strip()
    }
    missing = [
        task
        for task in active_tasks
        if not (
            raw_by_title.get((task.title or "").strip().lower())
            and raw_by_title[(task.title or "").strip().lower()].tip.strip()
        )
    ]
    if not missing:
        return raw_items

    task_lines = []
    for task in missing[:30]:
        task_lines.append(
            f"- {task.title} | Course: {task.courseName or 'N/A'} "
            f"| Deadline: {task.deadline if task.hasRealDeadline is not False else 'none'} "
            f"| Est: {task.estimatedMinutes or 60} min "
            f"| Description: {(task.description or '').strip()[:240]}"
        )

    tip_prompt = "\n".join(
        [
            "Write concrete study tips for the tasks below.",
            "Do not schedule tasks and do not invent task titles.",
            "Each tip must be specific to the task deliverable, 20-35 words.",
            "Return valid JSON only with this schema:",
            '{"items":[{"taskTitle":"exact title","tip":"specific tip"}]}',
            "",
            *task_lines,
        ]
    )

    try:
        parsed, _ = _llm_provider.generate_json(
            messages=[
                {"role": "system", "content": system_message},
                {"role": "user", "content": tip_prompt},
            ],
            model=_llm_config.plan_model,
            fallback_model=_llm_config.plan_fallback_model,
            provider=_llm_config.plan_provider,
            fallback_provider=_llm_config.plan_fallback_provider,
            temperature=0.35,
            max_tokens=max(700, min(3000, len(missing) * 90)),
        )
    except Exception as exc:
        logger.warning("[Planner] missing-tip LLM pass failed: %s", type(exc).__name__)
        return raw_items

    merged = list(raw_items)
    index_by_title = {
        (item.taskTitle or "").strip().lower(): index
        for index, item in enumerate(merged)
        if (item.taskTitle or "").strip()
    }
    active_by_title = {
        (task.title or "").strip().lower(): task
        for task in active_tasks
        if (task.title or "").strip()
    }

    for raw in parsed.get("items", []):
        title = str(raw.get("taskTitle", "")).strip()
        tip = str(raw.get("tip", "")).strip()
        key = title.lower()
        if not title or not tip or key not in active_by_title:
            continue

        existing_index = index_by_title.get(key)
        if existing_index is not None:
            existing = merged[existing_index]
            if not existing.tip.strip():
                merged[existing_index] = existing.model_copy(update={"tip": tip})
            continue

        task = active_by_title[key]
        index_by_title[key] = len(merged)
        merged.append(
            PlanItem(
                taskTitle=task.title,
                courseName=task.courseName or "",
                suggestedDate="",
                suggestedTime="",
                hoursNeeded=_task_estimated_hours(task),
                priority=_effective_priority(task),
                tip=tip,
            )
        )

    return merged


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
    hours = _task_estimated_hours(task)
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
    suggested_date = suggested.strftime("%Y-%m-%d")

    return PlanItem(
        taskId=task.id,
        taskTitle=task.title,
        courseName=task.courseName or "",
        deadline=task.deadline if task.hasRealDeadline is not False else None,
        status=task.status or "pending",
        suggestedDate=suggested_date,
        suggestedTime=_format_study_window(
            [0, 4, 8][index % 3],
            hours,
            _deadline_minutes_for_date(task, suggested_date),
        ),
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
    near-deadline pending work first, missed catch-up work next, and all tasks
    packed against the student's daily study capacity.
    """
    now = now or datetime.now()
    daily_overrides = daily_overrides or {}
    ordered_tasks = sorted(active_tasks, key=lambda task: _planning_sort_key(task, now))
    items = _normalize_plan_items_to_capacity(
        [],
        ordered_tasks,
        now,
        default_daily_hours=default_daily_hours,
        daily_overrides=daily_overrides,
    )

    today_str = now.strftime("%Y-%m-%d")
    due_today = sum(1 for it in items if it.suggestedDate == today_str)
    overdue = sum(
        1 for it in items if (it.status or "").lower() in {"missed", "overdue"}
    )

    parts = [
        f"Here is a risk-aware plan for your {len(items)} task"
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
        "exact time the student expects to spend. Convert Est minutes to "
        "hoursNeeded exactly (120 min = 2h, 30 min = 0.5h); do not inflate or "
        "shrink it. Pack days up to the capacity above. A day may go over only "
        "when an indivisible task forces it, and never by more than 1 hour "
        "unless that single task is longer than the day's capacity. If "
        "everything does not fit, push lower-priority tasks to later days while "
        "still finishing before each deadline."
    )
    lines += capacity_lines

    lines += [
        "",
        "Your job: act like the student personally sitting down to plan their week.",
        "Produce a realistic, day-by-day schedule that a real person could follow.",
        "",
        "Scheduling rules (follow them strictly and logically):",
        "0. SUCCESS RULE: do not create a new missed task while catching up. "
        "Pending or in-progress tasks with urgent/high priority and real "
        "upcoming deadlines must be scheduled before missed/overdue catch-up "
        "tasks. Missed tasks are important, but they come after imminent "
        "pending deadlines.",
        "1. ORDER by risk: first upcoming urgent pending/in-progress tasks, "
        "then upcoming high pending/in-progress tasks, then missed/overdue "
        "catch-up work, then medium/low tasks. Within each group, use the "
        "earliest real deadline first.",
        "2. FINISH-BEFORE-DEADLINE: schedule each task to be completed at least one "
        "full day BEFORE its deadline whenever possible (buffer for the unexpected). "
        "Never schedule a pending/in-progress task after its deadline date or "
        "after its exact deadline time. If the one-day buffer is impossible, "
        "use the deadline day before moving any missed catch-up task ahead of it.",
        "4. REALISTIC LOAD: respect the student's daily study capacity stated "
        "above. Do not pile tasks into a day beyond the configured hours. Sum "
        "each day's hoursNeeded and keep it within the limit, with at most a "
        "small 1h overflow for indivisible tasks. If a day still has capacity, "
        "add the next most important unfinished task that fits instead of "
        "leaving useful study time empty.",
        "5. CHRONOLOGICAL DAYS: use real calendar dates. Today is "
        f"{today_str}; tomorrow is {tomorrow_str}. Spread tasks across consecutive "
        "days starting today.",
        "6. Allocate sensible time windows (e.g. '14:00 – 16:00') whose length "
        "matches each task's expected hours ('Est:' value). The hoursNeeded "
        "field must equal Est minutes divided by 60.",
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

    # Risk-aware order: imminent pending/in-progress work first, then missed
    # catch-up. This prevents old missed tasks from causing a fresh deadline miss.
    now_for_ordering = datetime.now()
    active_tasks.sort(key=lambda task: _planning_sort_key(task, now_for_ordering))
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
            provider=_llm_config.plan_provider,
            fallback_provider=_llm_config.plan_fallback_provider,
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

    active_title_keys = {
        (t.title or "").strip().lower()
        for t in active_tasks
        if (t.title or "").strip()
    }

    raw_items: List[PlanItem] = []
    for raw in parsed.get("items", []):
        title_key = str(raw.get("taskTitle", "")).strip().lower()
        if title_key not in active_title_keys:
            continue

        try:
            raw_hours = float(raw.get("hoursNeeded", 1))
        except (TypeError, ValueError):
            raw_hours = 1.0

        raw_items.append(
            PlanItem(
                taskTitle=str(raw.get("taskTitle", "")),
                courseName=str(raw.get("courseName", "")),
                suggestedDate=raw.get("suggestedDate", ""),
                suggestedTime=raw.get("suggestedTime", ""),
                hoursNeeded=raw_hours,
                priority=str(raw.get("priority", "medium")),
                tip=str(raw.get("tip", "")),
                description=raw.get("description"),
            )
        )

    raw_items = _fill_missing_llm_tips(raw_items, active_tasks, system_message)

    # Normalize the finish scenario chronologically (today -> later) while
    # correcting bad estimates,
    # overloaded days, and any LLM omissions.
    items = _normalize_plan_items_to_capacity(
        raw_items,
        active_tasks,
        datetime.now(),
        default_daily_hours=default_hours,
        daily_overrides=daily_overrides,
    )

    # ── Optional judge evaluation (non-blocking) ───────────────────────────────
    judge_meta: Optional[Dict[str, Any]] = None
    if _llm_judge and _llm_config.enable_study_plan_judge:
        verdict = _llm_judge.evaluate_study_plan(
            plan_items=[i.model_dump() for i in items],
            input_tasks=[t.model_dump() for t in active_tasks],
            summary=parsed.get("summary", ""),
            generator_model=gen_result.model,
            system_prompt=system_message,
            user_prompt=prompt,
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
        "provider": _llm_config.plan_provider,
        "fallback": _llm_config.plan_fallback_model,
        "fallback_provider": _llm_config.plan_fallback_provider,
    }
