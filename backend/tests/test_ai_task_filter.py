import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(
    0,
    os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "ai"),
)

from task_filter import filter_real_tasks, is_real_task


def test_is_real_task_keeps_assignments():
    assert is_real_task("Database Normalization Project") is True
    assert is_real_task("Mini Project 2") is True


def test_is_real_task_excludes_grade_entries():
    assert is_real_task("Midterm Grades") is False
    assert is_real_task("Quiz 3 grades") is False
    assert is_real_task("Labs grades") is False


def test_is_real_task_excludes_in_class_lab_activities():
    assert is_real_task("Lab08 - Zombie machines") is False
    assert is_real_task("Lap06-Convert Channel") is False
    assert is_real_task("lab_participation week 4") is False
    assert is_real_task("Final Lab") is False


def test_filter_real_tasks_removes_non_deliverables():
    tasks = [
        {"title": "ER Diagram Assignment", "id": "1"},
        {"title": "Midterm Grades", "id": "2"},
        {"title": "Lab08 - Steganography", "id": "3"},
        {"title": "Normalization HW", "id": "4"},
    ]

    kept = filter_real_tasks(tasks)

    titles = [t["title"] for t in kept]
    assert titles == ["ER Diagram Assignment", "Normalization HW"]


def test_filter_real_tasks_removes_empty_title_without_deadline_or_signal():
    tasks = [{"title": "", "id": "1"}]
    kept = filter_real_tasks(tasks)
    assert kept == []
