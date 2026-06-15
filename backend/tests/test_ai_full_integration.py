"""
Frontend-shaped AI integration: classroom tasks → planner + chat (mocked Groq).
Simulates payloads the Flutter app sends to /api/plan/generate and /api/chat/message.
"""
import json
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from app.main import app
from app.api.routes import planner, chat as chat_route

client = TestClient(app)


class IntegrationGroqClient:
    """Single mock Groq client shared by planner route tests."""

    def chat_completion(self, messages, **kwargs):
        user_content = messages[-1]["content"]
        if "active tasks" in user_content.lower() or "student name" in user_content.lower():
            return {
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "items": [
                                        {
                                            "taskTitle": "Database Normalization HW",
                                            "courseName": "Database Systems",
                                            "suggestedDate": "2026-06-14",
                                            "suggestedTime": "15:00 – 17:00",
                                            "hoursNeeded": 2,
                                            "priority": "high",
                                            "tip": "Review 3NF examples before starting.",
                                        }
                                    ],
                                    "summary": "Focus on normalization homework first.",
                                }
                            )
                        }
                    }
                ]
            }
        return {
            "choices": [
                {
                    "message": {
                        "content": "Start with Database Normalization HW — it is your highest priority task.",
                    }
                }
            ],
            "model": "llama-3.3-70b-versatile",
        }


class IntegrationChatService:
    def __init__(self):
        self.client = IntegrationGroqClient()
        self.system_prompt = "You are a study assistant."

    def chat(self, user_message, conversation_history=None, student_context=None):
        messages = [{"role": "system", "content": self.system_prompt}]
        if conversation_history:
            messages.extend(conversation_history)
        messages.append({"role": "user", "content": user_message})
        response = self.client.chat_completion(messages=messages)
        return {
            "success": True,
            "message": response["choices"][0]["message"]["content"],
            "model": response.get("model", "llama-3.3-70b-versatile"),
        }

    def get_quick_suggestions(self, student_context=None):
        return ["What should I study now?", "Help me prioritize my tasks"]


def _flutter_task_payload():
    """Mirrors ApiService.generateStudyPlan() task JSON from Flutter Task.toJson()."""
    return [
        {
            "id": "task_db_1",
            "title": "Database Normalization HW",
            "courseName": "Database Systems",
            "deadline": "2026-06-15T23:59:00.000",
            "estimatedMinutes": 120,
            "priority": "high",
            "status": "pending",
            "description": None,
            "assignedGrade": None,
            "maxPoints": 100,
        },
        {
            "id": "task_grade",
            "title": "Quiz 2 grades",
            "courseName": "Database Systems",
            "deadline": "2026-06-10T12:00:00.000",
            "estimatedMinutes": 0,
            "priority": "medium",
            "status": "pending",
        },
        {
            "id": "task_done",
            "title": "Completed Lab Report",
            "courseName": "Database Systems",
            "deadline": "2026-06-01T23:59:00.000",
            "estimatedMinutes": 90,
            "priority": "medium",
            "status": "completed",
        },
    ]


def test_ai_stack_health_integration():
    plan_health = client.get("/api/plan/health")
    chat_health = client.get("/api/chat/health")

    assert plan_health.status_code == 200
    assert chat_health.status_code == 200
    assert "status" in plan_health.json()
    assert "status" in chat_health.json()


def test_flutter_to_planner_ai_flow(monkeypatch):
    monkeypatch.setattr(planner, "groq_client", IntegrationGroqClient())

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "tasks": _flutter_task_payload(),
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["studentName"] == "Pakinam"
    assert len(data["items"]) == 1
    assert data["items"][0]["taskTitle"] == "Database Normalization HW"
    assert "normalization" in data["summary"].lower()


def test_flutter_to_chat_ai_flow(monkeypatch):
    monkeypatch.setattr(chat_route, "chat_service", IntegrationChatService())

    response = client.post(
        "/api/chat/message",
        json={
            "message": "What should I study now?",
            "conversation_history": [
                {"role": "assistant", "content": "Hi Pakinam!"},
            ],
            "student_context": {
                "name": "Pakinam",
                "tasks": [
                    {
                        "title": "Database Normalization HW",
                        "courseName": "Database Systems",
                        "priority": "high",
                        "status": "pending",
                        "deadline": "2026-06-15T23:59:00.000",
                        "estimatedMinutes": 120,
                    }
                ],
            },
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "normalization" in data["message"].lower()
    assert data["suggestions"]


def test_full_student_ai_journey(monkeypatch):
    """Tasks → study plan → follow-up chat question (mocked LLM)."""
    monkeypatch.setattr(planner, "groq_client", IntegrationGroqClient())
    monkeypatch.setattr(chat_route, "chat_service", IntegrationChatService())

    tasks = _flutter_task_payload()

    plan_response = client.post(
        "/api/plan/generate",
        json={"studentName": "Pakinam", "tasks": tasks},
    )
    assert plan_response.status_code == 200
    plan = plan_response.json()
    top_task = plan["items"][0]["taskTitle"]

    chat_response = client.post(
        "/api/chat/message",
        json={
            "message": f"Tell me more about {top_task}",
            "student_context": {"name": "Pakinam", "tasks": tasks[:1]},
        },
    )
    assert chat_response.status_code == 200
    assert chat_response.json()["success"] is True
