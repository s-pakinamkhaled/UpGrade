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

    def test_missed_assignment_is_low_priority(self):
        task = TaskInput(
            id="a8",
            title="Assignment 8",
            deadline="2026-05-16T23:59:00",
            hasRealDeadline=True,
            status="missed",
            priority="low",
        )

        self.assertEqual(_effective_priority(task), "low")


if __name__ == "__main__":
    unittest.main()
