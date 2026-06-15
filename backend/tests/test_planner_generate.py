import sys
import os
import json

sys.path.append(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

from fastapi.testclient import TestClient
from app.main import app
from app.api.routes import planner

client = TestClient(app)


class MockGroqClient:
    def chat_completion(self, **kwargs):
        return {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(
                            {
                                "items": [
                                    {
                                        "taskTitle": "AI Assignment",
                                        "courseName": "AI",
                                        "suggestedDate": "2026-06-20",
                                        "suggestedTime": "10:00-12:00",
                                        "hoursNeeded": 2,
                                        "priority": "high",
                                        "tip": "Start early",
                                    }
                                ],
                                "summary": "Test summary",
                            }
                        )
                    }
                }
            ]
        }


def test_generate_plan_success(monkeypatch):
    monkeypatch.setattr(
        planner,
        "groq_client",
        MockGroqClient(),
    )

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "tasks": [
                {
                    "id": "1",
                    "title": "AI Assignment",
                    "status": "pending",
                }
            ],
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["success"] is True


class BadGroqClient:
    def chat_completion(self, **kwargs):
        return {
            "choices": [
                {
                    "message": {
                        "content": "NOT JSON",
                    }
                }
            ]
        }


def test_generate_plan_invalid_json(monkeypatch):
    monkeypatch.setattr(
        planner,
        "groq_client",
        BadGroqClient(),
    )

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "tasks": [
                {
                    "id": "1",
                    "title": "Task",
                }
            ],
        },
    )

    assert response.status_code == 502


class ErrorGroqClient:
    def chat_completion(self, **kwargs):
        return {
            "error": "API failed",
        }


def test_generate_plan_groq_error(monkeypatch):
    monkeypatch.setattr(
        planner,
        "groq_client",
        ErrorGroqClient(),
    )

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "tasks": [
                {
                    "id": "1",
                    "title": "Task",
                }
            ],
        },
    )

    assert response.status_code == 502
