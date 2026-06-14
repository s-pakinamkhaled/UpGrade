import sys
import os
import json

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from app.main import app
from app.api.routes import planner
from app.api.routes.planner import PlanRequest, TaskInput, _build_prompt, _PRIORITY_RANK

client = TestClient(app)


def test_priority_rank_order():
    assert _PRIORITY_RANK["urgent"] < _PRIORITY_RANK["high"]
    assert _PRIORITY_RANK["high"] < _PRIORITY_RANK["medium"]


def test_build_prompt_includes_grade_info():
    request = PlanRequest(
        studentName="Student",
        tasks=[
            TaskInput(
                id="1",
                title="Database Report",
                assignedGrade=18.0,
                maxPoints=20,
            )
        ],
    )

    prompt = _build_prompt(request)

    assert "Grade: 18.0/20" in prompt


def test_generate_plan_filters_grade_and_lab_tasks(monkeypatch):
    class MockGroqClient:
        def chat_completion(self, **kwargs):
            user_prompt = kwargs["messages"][1]["content"]
            assert "Midterm Grades" not in user_prompt
            assert "Lab08" not in user_prompt
            assert "Normalization HW" in user_prompt
            return {
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "items": [
                                        {
                                            "taskTitle": "Normalization HW",
                                            "courseName": "Database",
                                            "suggestedDate": "2026-06-15",
                                            "suggestedTime": "14:00 – 16:00",
                                            "hoursNeeded": 2,
                                            "priority": "high",
                                            "tip": "Start with examples",
                                        }
                                    ],
                                    "summary": "One task plan.",
                                }
                            )
                        }
                    }
                ]
            }

    monkeypatch.setattr(planner, "groq_client", MockGroqClient())

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "tasks": [
                {"id": "1", "title": "Normalization HW", "status": "pending", "priority": "high"},
                {"id": "2", "title": "Midterm Grades", "status": "pending"},
                {"id": "3", "title": "Lab08 - Lab task", "status": "pending"},
                {"id": "4", "title": "Finished Essay", "status": "completed"},
            ],
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["items"][0]["taskTitle"] == "Normalization HW"


def test_generate_plan_strips_markdown_fences(monkeypatch):
    class FenceGroqClient:
        def chat_completion(self, **kwargs):
            return {
                "choices": [
                    {
                        "message": {
                            "content": "```json\n"
                            + json.dumps(
                                {
                                    "items": [
                                        {
                                            "taskTitle": "AI Assignment",
                                            "courseName": "AI",
                                            "suggestedDate": "2026-06-20",
                                            "suggestedTime": "10:00-12:00",
                                            "hoursNeeded": 2,
                                            "priority": "medium",
                                            "tip": "Review slides",
                                        }
                                    ],
                                    "summary": "Plan ready.",
                                }
                            )
                            + "\n```"
                        }
                    }
                ]
            }

    monkeypatch.setattr(planner, "groq_client", FenceGroqClient())

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "tasks": [{"id": "1", "title": "AI Assignment", "status": "pending"}],
        },
    )

    assert response.status_code == 200
    assert response.json()["success"] is True
