import os
import sys
import unittest
from types import SimpleNamespace


PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
AI_PATH = os.path.join(PROJECT_ROOT, "ai")
sys.path.insert(0, AI_PATH)

from task_filter import filter_real_tasks, is_actionable_task  # noqa: E402


class TaskFilterTests(unittest.TestCase):
    def test_excludes_grade_and_summary_titles(self):
        titles = [
            "Lecture Quizzes [5]",
            "Midterm Grades",
            "Final Lab Grade",
            "Total Course Work",
            "Course Work",
            "Total Assignments",
            "Assignment 7 Grade",
            "Lab grades",
            "Quiz Grade",
            "Debate Quiz",
            "Outline Quiz",
            "Sample Essay Marking",
            "Persuasive Essay Outline (6%)",
            "Lab03- Practical",
            "Public Speaking Assessment 2%",
            "Public Speaking Assessment Instructions and Rubric",
        ]

        for title in titles:
            with self.subTest(title=title):
                self.assertFalse(
                    is_actionable_task(
                        {
                            "title": title,
                            "status": "pending",
                            "deadline": "2026-06-20T23:59:00",
                        }
                    )
                )

    def test_includes_real_unfinished_deliverables(self):
        tasks = [
            {"title": "Assignment 7", "status": "pending", "deadline": "2026-06-20"},
            {
                "title": "Assignment 7: Git + DVC + Docker + CI/CD Workflow (not graded)",
                "status": "pending",
                "deadline": "2026-06-20",
            },
            {"title": "Project Report", "status": "inProgress", "deadline": "2026-06-21"},
            {"title": "Lab delivery", "status": "missed", "deadline": "2026-06-01"},
        ]

        self.assertEqual(filter_real_tasks(tasks), tasks)

    def test_metadata_wins_over_title(self):
        self.assertFalse(
            is_actionable_task(
                {
                    "title": "Assignment 7",
                    "status": "pending",
                    "assignedGrade": 9,
                    "deadline": "2026-06-20",
                }
            )
        )
        self.assertFalse(
            is_actionable_task(
                {
                    "title": "Project Report",
                    "itemType": "completed_work",
                    "isActionableForAI": False,
                    "status": "completed",
                }
            )
        )
        self.assertTrue(
            is_actionable_task(
                {
                    "title": "Task Section",
                    "itemType": "actionable_task",
                    "isActionableForAI": True,
                    "isGradeRelated": False,
                    "isDashboardOnly": False,
                    "status": "pending",
                }
            )
        )

    def test_backend_rejects_stale_actionable_label_for_assessment_rows(self):
        self.assertFalse(
            is_actionable_task(
                {
                    "title": "Debate Quiz",
                    "status": "pending",
                    "deadline": "2026-06-15",
                    "itemType": "actionable_task",
                    "isActionableForAI": True,
                    "isGradeRelated": False,
                    "isDashboardOnly": False,
                    "hasRealDeadline": True,
                }
            )
        )

        self.assertFalse(
            is_actionable_task(
                {
                    "title": "Lab03- Practical",
                    "status": "pending",
                    "deadline": "2026-06-14",
                    "itemType": "actionable_task",
                    "isActionableForAI": True,
                    "isGradeRelated": False,
                    "isDashboardOnly": False,
                    "hasRealDeadline": True,
                }
            )
        )
        self.assertFalse(
            is_actionable_task(
                {
                    "title": "Public Speaking Assessment 2%",
                    "status": "pending",
                    "deadline": "2026-06-14",
                    "itemType": "actionable_task",
                    "isActionableForAI": True,
                    "isGradeRelated": False,
                    "isDashboardOnly": False,
                    "hasRealDeadline": True,
                }
            )
        )

    def test_supports_object_style_tasks_from_pydantic(self):
        tasks = [
            SimpleNamespace(
                title="Assignment 8",
                status="pending",
                deadline="2026-06-20",
                assignedGrade=None,
                itemType="actionable_task",
                isActionableForAI=True,
                isGradeRelated=False,
                isDashboardOnly=False,
            ),
            SimpleNamespace(
                title="Total Assignments",
                status="pending",
                deadline="2026-06-20",
                assignedGrade=None,
                itemType="grade_bucket",
                isActionableForAI=False,
                isGradeRelated=True,
                isDashboardOnly=True,
            ),
        ]

        filtered = filter_real_tasks(tasks)
        self.assertEqual(len(filtered), 1)
        self.assertEqual(filtered[0].title, "Assignment 8")


if __name__ == "__main__":
    unittest.main()
