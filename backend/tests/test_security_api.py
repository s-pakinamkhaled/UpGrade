import sys
import os
from datetime import datetime

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from app.main import app
from app.api.routes import chat as chat_route

client = TestClient(app)


class MockChatService:
    def chat(self, user_message, conversation_history=None, student_context=None):
        return {"success": True, "message": "ok", "model": "test"}

    def get_quick_suggestions(self, student_context=None):
        return ["Help"]


def test_tasks_reject_unsafe_path_ids():
    response = client.get("/api/tasks/task%3Fx")
    assert response.status_code == 400

    response = client.patch(
        "/api/tasks/task%3Fx/status",
        json={"status": "pending", "userId": "student1"},
    )
    assert response.status_code in (400, 404)


def test_tasks_sanitize_xss_like_title_on_upsert():
    response = client.post(
        "/api/tasks",
        json={
            "id": "sec_task_001",
            "userId": "student_sec",
            "title": "  <script>alert(1)</script>  ",
            "status": "pending",
            "updatedAt": datetime.utcnow().isoformat(),
        },
    )
    assert response.status_code == 200
    title = response.json()["task"]["title"]
    assert title == "<script>alert(1)</script>"
    assert title == title.strip()


def test_tasks_reject_unsafe_ids_on_upsert():
    response = client.post(
        "/api/tasks",
        json={
            "id": "../evil",
            "userId": "student1",
            "status": "pending",
            "updatedAt": datetime.utcnow().isoformat(),
        },
    )
    assert response.status_code == 400


def test_profile_rejects_unsafe_user_id():
    response = client.get("/api/profile/user%3Fx")
    assert response.status_code == 400


def test_profile_rejects_invalid_email_on_update():
    response = client.patch(
        "/api/profile/sec_user_001",
        json={
            "fullName": "Pakinam",
            "email": "not-valid",
            "major": "AI",
        },
    )
    assert response.status_code == 400


def test_profile_sanitizes_display_fields():
    response = client.patch(
        "/api/profile/sec_user_002",
        json={
            "fullName": "  Pakinam   Ahmed  ",
            "email": "pakinam@test.com",
            "major": "  Computer   Science  ",
        },
    )
    assert response.status_code == 200
    profile = response.json()["profile"]
    assert profile["fullName"] == "Pakinam Ahmed"
    assert profile["major"] == "Computer Science"


def test_study_groups_reject_unsafe_group_id():
    response = client.patch(
        "/api/study-groups/group%3Fx/status",
        json={"status": "active"},
    )
    assert response.status_code in (400, 404)


def test_study_groups_reject_unsafe_user_query():
    response = client.get(
        "/api/study-groups/my-groups",
        params={"userId": "../admin"},
    )
    assert response.status_code == 400


def test_notifications_filters_invalid_invite_emails():
    response = client.post(
        "/api/notifications/course-room-invite",
        json={
            "recipientEmails": ["bad-email", "valid@test.com", "valid@test.com"],
            "courseName": "  Database  ",
            "inviterName": "  Pakinam  ",
        },
    )
    assert response.status_code in (200, 503)
    if response.status_code == 200:
        assert response.json()["sent"] == 0


def test_chat_rejects_empty_message(monkeypatch):
    monkeypatch.setattr(chat_route, "chat_service", MockChatService())

    response = client.post(
        "/api/chat/message",
        json={"message": "   "},
    )
    assert response.status_code == 400


def test_chat_rejects_oversized_message(monkeypatch):
    monkeypatch.setattr(chat_route, "chat_service", MockChatService())

    response = client.post(
        "/api/chat/message",
        json={"message": "A" * 5000},
    )
    assert response.status_code == 400


def test_chat_accepts_valid_message(monkeypatch):
    monkeypatch.setattr(chat_route, "chat_service", MockChatService())

    response = client.post(
        "/api/chat/message",
        json={"message": "What should I study now?"},
    )
    assert response.status_code == 200
