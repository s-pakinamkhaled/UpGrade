import sys
import os

sys.path.append(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

from app.api.routes.planner import (
    PlanRequest,
    TaskInput,
    _build_prompt,
)


def test_build_prompt_contains_student_name():
    request = PlanRequest(
        studentName="Pakinam",
        tasks=[
            TaskInput(
                id="1",
                title="AI Assignment",
            )
        ],
    )

    prompt = _build_prompt(request)

    assert "Pakinam" in prompt


def test_build_prompt_contains_task_title():
    request = PlanRequest(
        studentName="Student",
        tasks=[
            TaskInput(
                id="1",
                title="Database Project",
            )
        ],
    )

    prompt = _build_prompt(request)

    assert "Database Project" in prompt


def test_build_prompt_contains_priority():
    request = PlanRequest(
        studentName="Student",
        tasks=[
            TaskInput(
                id="1",
                title="OS Project",
                priority="high",
            )
        ],
    )

    prompt = _build_prompt(request)

    assert "HIGH" in prompt


def test_multiple_tasks_in_prompt():
    request = PlanRequest(
        studentName="Student",
        tasks=[
            TaskInput(id="1", title="Task A"),
            TaskInput(id="2", title="Task B"),
        ],
    )

    prompt = _build_prompt(request)

    assert "Task A" in prompt
    assert "Task B" in prompt
