"""
Metadata-first task filtering for AI features.

The app keeps every synced Google Classroom row for dashboard and analytics.
This module decides which rows are safe to expose to the LLM as schedulable
tasks. It is intentionally duplicated server-side as a guard against older
clients, malformed payloads, or prompt-only filtering mistakes.
"""

from __future__ import annotations

import re
from typing import Any, Dict, Iterable, List, Optional, Union

TaskLike = Union[Dict[str, Any], Any]

NON_ACTIONABLE_TYPES = {
    "grade_item",
    "grade_bucket",
    "completed_work",
    "material",
    "dashboard_only",
}

ACTIONABLE_TYPES = {"actionable_task"}

COMPLETED_STATUSES = {
    "completed",
    "returned",
    "submitted",
    "graded",
    "turned_in",
    "turnedin",
    "reclaimed_by_student",
}

ACTIONABLE_STATUSES = {"pending", "inprogress", "in_progress", "missed"}

EXACT_GRADE_TITLES = {
    "grades",
    "grade",
    "score",
    "scores",
    "marks",
    "result",
    "results",
    "total",
    "total course work",
    "course work",
    "coursework",
    "total assignments",
    "total labs grades",
    "total labs",
    "overall grade",
    "course grade",
}

STRONG_GRADE_SUBSTRINGS = [
    "labs grades",
    "labs grade",
    "lab grades",
    "lab grade",
    "quiz grades",
    "quiz grade",
    "quizzes grade",
    "quizzes grades",
    "lecture quizzes",
    "lecture quiz grades",
    "lecture quiz grade",
    "midterm grades",
    "midterm grade",
    "final grade",
    "final lab grade",
    "final lab exam grade",
    "attendance grades",
    "attendance grade",
    "term work grades",
    "term work grade",
    "lab assignments grades",
    "lab quiz grades",
    "mini project grades",
    "sample essay marking",
    "essay marking",
    "marking",
    "instructions and rubric",
    "total course work",
    "total assignments",
]

GRADE_REGEX_PATTERNS = [
    (
        re.compile(r"\bassignment\s+\d+\s+grades?\b", re.I),
        None,
    ),
    (
        re.compile(r"\bgrades?\s*(\[[\d.%]+\]|\([\d.%]+\))?\s*$", re.I),
        re.compile(
            r"\b(project|report|homework|delivery|submission|practical|task|exercise)\b",
            re.I,
        ),
    ),
    (
        re.compile(r"^total\s+", re.I),
        re.compile(r"\b(project|report|task)\b", re.I),
    ),
    (
        re.compile(r"^midterm\s*(\(\d+[%]?\)|\d+\s*%)", re.I),
        None,
    ),
    (
        re.compile(r"^\s*(lab|lap)\s*\d+\b", re.I),
        re.compile(
            r"\b(delivery|practice|report|submission|homework|assignment|project)\b",
            re.I,
        ),
    ),
    (
        re.compile(r"\[[\d.]+\]\s*$", re.I),
        re.compile(
            r"\b(assignment|project|homework|report|task|delivery|submission)\b",
            re.I,
        ),
    ),
    (
        re.compile(r"\(\s*\d+(\.\d+)?\s*%\s*\)\s*$", re.I),
        re.compile(
            r"\b(assignment|project|homework|report|task|delivery|submission)\b",
            re.I,
        ),
    ),
    (
        re.compile(r"\b\d+(\.\d+)?\s*%\s*$", re.I),
        re.compile(
            r"\b(assignment|project|homework|report|task|delivery|submission)\b",
            re.I,
        ),
    ),
    (
        re.compile(r"\b(assessment|rubric)\b", re.I),
        re.compile(
            r"\b(assignment|homework|submission|delivery|project|report|essay|outline)\b",
            re.I,
        ),
    ),
    (
        re.compile(r"\bquiz(zes)?\b", re.I),
        re.compile(
            r"\b(assignment|homework|submission|delivery|project|report|prep|prepare|study|review|practice)\b",
            re.I,
        ),
    ),
    (
        re.compile(r"\bmarking\b", re.I),
        None,
    ),
]

ACTIONABLE_SIGNAL_RE = re.compile(
    r"\b(assignment|project|task|homework|hw|report|delivery|submission|"
    r"practical|exercise|case\s+study|mini\s*project|presentation|"
    r"proposal|paper|essay|worksheet|lab\s*report)\b",
    re.I,
)


def _get(task: TaskLike, field: str, default: Any = None) -> Any:
    if isinstance(task, dict):
        return task.get(field, default)
    return getattr(task, field, default)


def _as_bool(value: Any) -> Optional[bool]:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "1", "yes"}:
            return True
        if lowered in {"false", "0", "no"}:
            return False
    return None


def _normalized_title(task: TaskLike) -> str:
    title = str(_get(task, "title", "") or "")
    return re.sub(r"\s+", " ", title.lower()).strip()


def title_looks_grade_related(title_lower: str) -> bool:
    if not title_lower:
        return False
    if title_lower in EXACT_GRADE_TITLES:
        return True
    if any(pattern in title_lower for pattern in STRONG_GRADE_SUBSTRINGS):
        return True
    for regex, guard in GRADE_REGEX_PATTERNS:
        if regex.search(title_lower):
            if guard is not None and guard.search(title_lower):
                continue
            return True
    return False


def is_actionable_task(task: TaskLike) -> bool:
    """
    Return True only for unfinished deliverables that can be scheduled.
    Metadata wins over title heuristics.
    """
    item_type = str(_get(task, "itemType", "") or "").strip().lower()
    is_actionable = _as_bool(_get(task, "isActionableForAI"))
    is_grade = _as_bool(_get(task, "isGradeRelated"))
    is_dashboard = _as_bool(_get(task, "isDashboardOnly"))

    if item_type in NON_ACTIONABLE_TYPES:
        return False
    if is_grade is True or is_dashboard is True or is_actionable is False:
        return False

    if _get(task, "assignedGrade") is not None:
        return False

    status = str(_get(task, "status", "") or "pending").replace("-", "_").lower()
    if status in COMPLETED_STATUSES:
        return False

    submission_state = (
        str(_get(task, "classroomSubmissionState", "") or "")
        .replace("-", "_")
        .lower()
    )
    if submission_state in COMPLETED_STATUSES:
        return False

    work_type = str(_get(task, "classroomWorkType", "") or "").upper()
    if work_type == "MATERIAL":
        return False

    title_lower = _normalized_title(task)
    if title_looks_grade_related(title_lower):
        return False

    if item_type in ACTIONABLE_TYPES and is_actionable is True:
        return True

    if status and status not in ACTIONABLE_STATUSES:
        return False

    # Older clients may not send classification metadata. If a row survived
    # grade/status/material checks, keep it only when it has a deadline or a
    # clear deliverable title signal.
    has_real_deadline = _get(task, "hasRealDeadline")
    deadline = _get(task, "deadline")
    if deadline and has_real_deadline is not False:
        return True
    return bool(ACTIONABLE_SIGNAL_RE.search(title_lower))


def is_real_task(task_or_title: TaskLike) -> bool:
    """Backward-compatible alias for older tests and callers."""
    if isinstance(task_or_title, str):
        return is_actionable_task({"title": task_or_title})
    return is_actionable_task(task_or_title)


def filter_real_tasks(
    tasks: Iterable[TaskLike],
    title_key: str = "title",
) -> List[TaskLike]:
    kept: List[TaskLike] = []
    removed_titles: List[str] = []

    for task in tasks:
        if is_actionable_task(task):
            kept.append(task)
        else:
            removed_titles.append(str(_get(task, title_key, "<no title>") or "<no title>"))

    if removed_titles:
        print(
            f"[TaskFilter] Received {len(kept) + len(removed_titles)} items, "
            f"using {len(kept)} actionable tasks for AI. Removed "
            f"{len(removed_titles)}: "
            + ", ".join(f'"{title}"' for title in removed_titles[:10])
            + (f" ... and {len(removed_titles) - 10} more" if len(removed_titles) > 10 else "")
        )
    else:
        print(f"[TaskFilter] Received {len(kept)} items, all passed filter.")

    return kept
