"""
Frontend-shaped AI integration: classroom tasks → planner + chat (mocked LLM).
Simulates payloads the Flutter app sends to /api/plan/generate and /api/chat/message.

Updated: patches _llm_provider (LLMProvider) instead of the old groq_client.
"""
import json
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from app.main import app
from app.api.routes import planner, chat as chat_route

client = TestClient(app)

_AI_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "ai"
)
if _AI_PATH not in sys.path:
    sys.path.insert(0, _AI_PATH)

from llm.provider import GenerationResult


class IntegrationLLMProvider:
    """Mock LLMProvider returning a planner response for the integration tests."""

    def generate_json(self, messages, model, fallback_model, **kwargs):
        parsed = {
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
        result = GenerationResult(
            content=json.dumps(parsed),
            model=model,
            provider="groq",
            used_fallback=False,
        )
        return parsed, result

    def generate_text(self, messages, model, fallback_model, **kwargs):
        return GenerationResult(
            content="Start with Database Normalization HW — it is your highest priority task.",
            model=model,
            provider="groq",
            used_fallback=False,
        )


class IntegrationChatService:
    """Minimal chat service mock for integration tests."""

    def __init__(self):
        self.system_prompt = "You are a study assistant."

    def chat(self, user_message, conversation_history=None, student_context=None):
        task_title = "your highest priority task"
        if student_context and student_context.get("tasks"):
            first = student_context["tasks"][0]
            task_title = first.get("title", task_title)
        return {
            "success": True,
            "message": f"Start with {task_title} — it is your highest priority.",
            "model": "llama-3.3-70b-versatile",
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
    monkeypatch.setattr(planner, "_llm_provider", IntegrationLLMProvider())

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
    monkeypatch.setattr(planner, "_llm_provider", IntegrationLLMProvider())
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
