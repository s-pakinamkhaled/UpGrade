import os
import sys
import unittest


PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
sys.path.insert(0, PROJECT_ROOT)

from backend.app.api.routes.planner import TaskInput, _effective_priority  # noqa: E402


class PlannerPriorityTests(unittest.TestCase):
    def test_no_deadline_assignment_is_low_priority(self):
        task = TaskInput(
            id="a7",
            title="Assignment 7",
            deadline="2026-06-14T23:59:00",
            hasRealDeadline=False,
            status="pending",
            priority="medium",
        )

        self.assertEqual(_effective_priority(task), "low")

    def test_missed_assignment_is_high_priority(self):
        # Missed work gets HIGH (not URGENT) so that pending tasks with very
        # tight upcoming deadlines (≤48h → urgent) rank above missed ones in the
        # study plan. This prevents the student from being overwhelmed by old
        # misses while a fresh deadline is imminent.
        task = TaskInput(
            id="a8",
            title="Assignment 8",
            deadline="2026-05-16T23:59:00",
            hasRealDeadline=True,
            status="missed",
            priority="low",
        )

        self.assertEqual(_effective_priority(task), "high")

    def test_overdue_pending_is_urgent(self):
        # A task that is technically past its deadline but still "pending"
        # (hours_left < 0) is treated as urgent since the student is already late.
        task = TaskInput(
            id="a9",
            title="Late Pending Task",
            deadline="2026-05-16T23:59:00",
            hasRealDeadline=True,
            status="pending",
            priority="medium",
        )

        self.assertEqual(_effective_priority(task), "urgent")

    def test_within_48h_is_urgent(self):
        from datetime import datetime, timedelta
        deadline = (datetime.now() + timedelta(hours=30)).isoformat()
        task = TaskInput(
            id="a10",
            title="Due Soon",
            deadline=deadline,
            hasRealDeadline=True,
            status="pending",
            priority="medium",
        )
        self.assertEqual(_effective_priority(task), "urgent")


if __name__ == "__main__":
    unittest.main()
