import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from app.main import app
from app.api.routes import chat as chat_route

client = TestClient(app)


class MockChatService:
    def chat(self, user_message, conversation_history=None, student_context=None):
        return {
            "success": True,
            "message": f"AI reply to: {user_message}",
            "model": "llama-3.3-70b-versatile",
        }

    def get_quick_suggestions(self, student_context=None):
        return ["What should I study now?", "Suggest a study schedule"]


def test_chat_message_success(monkeypatch):
    monkeypatch.setattr(chat_route, "chat_service", MockChatService())

    response = client.post(
        "/api/chat/message",
        json={
            "message": "What should I study now?",
            "conversation_history": [
                {"role": "user", "content": "Hi"},
                {"role": "assistant", "content": "Hello!"},
            ],
            "student_context": {
                "name": "Pakinam",
                "tasks": [{"title": "Database HW", "priority": "high"}],
            },
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "AI reply to" in data["message"]
    assert data["model"] == "llama-3.3-70b-versatile"
    assert len(data["suggestions"]) >= 1


def test_chat_message_unavailable_service(monkeypatch):
    monkeypatch.setattr(chat_route, "chat_service", None)

    response = client.post(
        "/api/chat/message",
        json={"message": "Hello"},
    )

    assert response.status_code == 503


def test_chat_message_service_error(monkeypatch):
    class BrokenChatService:
        def chat(self, **kwargs):
            raise RuntimeError("boom")

        def get_quick_suggestions(self, **kwargs):
            return []

    monkeypatch.setattr(chat_route, "chat_service", BrokenChatService())

    response = client.post(
        "/api/chat/message",
        json={"message": "Hello"},
    )

    assert response.status_code == 500
