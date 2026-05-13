"""
task_filter.py
==============
Filtering layer that removes non-student-task items (grade entries and
in-class lab activities) from the task list BEFORE the data is fed to the
LLM -- for both the study-planner and the AI chat features.

Two categories are excluded
---------------------------
1. Activity-type items that are NOT take-home work:
   * lab_participation  - instructor uploads lab material / resources
   * lab_task / Lab Practice - activities done live during the lab session
   * Any title that starts with "Lab<N>" or "Lap<N>" (e.g. Lab08, Lap06)
   * Final Lab, Lab Exams

2. Grade-entry items posted by instructors (not tasks for students):
   * Anything containing the word "grades" / "grade"
   * Midterm (grade announcements)
   * Quiz grades, Labs grades, etc.

Only genuine student deliverables (Assignments, Projects, Mini Projects,
graded take-home work) pass through the filter.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Union


# -- 1. Verbatim substring exclusions (case-insensitive) -----------------------
# If the task title CONTAINS any of these strings it is excluded.
_EXCLUDED_SUBSTRINGS: List[str] = [
    "lab_participation",
    "lab_task",
    "lab practice",
    "lab exams",
    "lab exam",
    "final lab",
    "labs grades",
    "labs grade",
    "quiz grades",
    "quiz grade",
    "midterm grades",
    "midterm grade",
]

# -- 2. Regex exclusions (case-insensitive) ------------------------------------
# If the task title MATCHES any of these patterns it is excluded.
_EXCLUDED_PATTERNS: List[re.Pattern] = [
    # Word "grade" or "grades" anywhere in the title
    # Catches: "Midterm Grades", "Quiz 3 Grades", "Quiz1 grades", "Labs grades"
    re.compile(r"\bgrades?\b", re.IGNORECASE),

    # Word "midterm" anywhere -- catches grade announcements like "Midterm Grades"
    re.compile(r"\bmidterm\b", re.IGNORECASE),

    # Standalone word "Labs" (plural) -- e.g. a section header posted as a task
    re.compile(r"\blabs\b", re.IGNORECASE),

    # Title starts with "Lab" or "Lap" immediately followed by digit(s)
    # Covers:  Lab08 - Zombie machines, Lap06-Convert Channel, Lap05-Steganography
    # Does NOT cover "Laboratory Report" or "Lab Report" (no digit after Lab/Lap)
    re.compile(r"^\s*(lab|lap)\s*\d+", re.IGNORECASE),
]


def is_real_task(title: str) -> bool:
    """
    Return True only when *title* looks like a genuine student deliverable.

    Items that are grade entries or in-class activities return False.
    An empty / missing title is kept (caller cannot determine its nature).
    """
    if not title:
        return True

    title_lower = title.lower().strip()

    for kw in _EXCLUDED_SUBSTRINGS:
        if kw in title_lower:
            return False

    for pattern in _EXCLUDED_PATTERNS:
        if pattern.search(title):
            return False

    return True


def filter_real_tasks(
    tasks: List[Union[Dict[str, Any], Any]],
    title_key: str = "title",
) -> List[Union[Dict[str, Any], Any]]:
    """
    Return a new list containing only genuine student tasks.

    Works with both plain ``dict`` objects and Pydantic / dataclass objects
    that expose a ``.title`` attribute (or the attribute named by *title_key*).

    Args:
        tasks:      List of task dicts or task model instances.
        title_key:  Key / attribute name that holds the task title.

    Returns:
        Filtered list -- same objects, just non-tasks removed.

    Side-effect:
        Prints a summary line when items are removed (visible in server logs).
    """
    def _get_title(task: Any) -> str:
        if isinstance(task, dict):
            return task.get(title_key) or ""
        return getattr(task, title_key, None) or ""

    kept: List = []
    removed_titles: List[str] = []

    for task in tasks:
        title = _get_title(task)
        if is_real_task(title):
            kept.append(task)
        else:
            removed_titles.append(title or "<no title>")

    if removed_titles:
        print(
            f"[TaskFilter] Removed {len(removed_titles)} non-task item(s) "
            f"from {len(tasks)} total: "
            + ", ".join(f'"{t}"' for t in removed_titles)
        )

    return kept
