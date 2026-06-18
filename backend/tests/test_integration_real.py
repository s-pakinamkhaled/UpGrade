import sys
import os
from datetime import datetime

sys.path.append(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_task_flow_integration():
    task = {
        "id": "integration_001",
        "userId": "student1",
        "title": "Database Project",
        "status": "pending",
        "updatedAt": datetime.utcnow().isoformat(),
    }

    # Create
    response = client.post("/api/tasks", json=task)
    assert response.status_code == 200

    # Read
    response = client.get("/api/tasks/integration_001")
    assert response.status_code == 200

    # Update
    response = client.patch(
        "/api/tasks/integration_001/status",
        json={
            "status": "inProgress",
            "userId": "student1",
        },
    )
    assert response.status_code == 200

    # Logs
    response = client.get("/api/tasks/activity/logs")
    assert response.status_code == 200


def test_profile_flow_integration():
    response = client.get("/api/profile/int_user")
    assert response.status_code == 200

    response = client.patch(
        "/api/profile/int_user",
        json={
            "fullName": "Pakinam Ahmed",
            "email": "pakinam@test.com",
        },
    )

    assert response.status_code == 200

    response = client.get("/api/profile/int_user")
    assert response.status_code == 200

    data = response.json()

    assert data["profile"]["fullName"] == "Pakinam Ahmed"


def test_study_group_flow_integration():
    response = client.post(
        "/api/study-groups/suggestions",
        json={
            "creatorId": "u1",
            "creatorName": "Pakinam",
            "courseId": "cs101",
            "courseName": "Database",
            "goal": "Finish project",
            "preferredMeetingTime": "18:00",
            "availableStart": "2026-06-01T18:00:00",
            "availableEnd": "2026-06-01T21:00:00",
            "topic": "Normalization",
        },
    )

    assert response.status_code == 200


def test_planner_health_integration():
    response = client.get("/api/plan/health")

    assert response.status_code == 200


def test_api_health_stack_integration():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["version"] == "1.0.0"

    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["services"]["backend"] == "running"


def test_chat_flow_integration():
    response = client.get("/api/chat/health")
    assert response.status_code == 200

    response = client.get("/api/chat/suggestions")
    assert response.status_code == 200
    assert "suggestions" in response.json()
    assert len(response.json()["suggestions"]) > 0


def test_notifications_flow_integration():
    response = client.post(
        "/api/notifications/course-room-invite",
        json={
            "recipientEmails": [],
            "courseName": "AI",
            "inviterName": "Pakinam",
        },
    )
    assert response.status_code == 200
    assert response.json()["sent"] == 0


def test_task_not_found_integration():
    response = client.get("/api/tasks/integration_missing_task_xyz")
    assert response.status_code == 404


def test_study_group_create_and_status_integration():
    creator_id = "integration_sg_user"
    payload = {
        "creatorId": creator_id,
        "creatorName": "Pakinam",
        "courseId": "cs101",
        "courseName": "Database",
        "goal": "Finish project",
        "preferredMeetingTime": "18:00",
        "availableStart": "2026-06-01T18:00:00",
        "availableEnd": "2026-06-01T21:00:00",
        "topic": "Normalization",
    }

    response = client.post("/api/study-groups/create", json=payload)
    assert response.status_code == 200

    group = response.json()["group"]
    group_id = group["groupId"]
    assert group["status"] == "pending"
    assert len(group["members"]) >= 2

    response = client.get(
        "/api/study-groups/my-groups",
        params={"userId": creator_id},
    )
    assert response.status_code == 200
    assert any(g["groupId"] == group_id for g in response.json()["groups"])

    response = client.patch(
        f"/api/study-groups/{group_id}/status",
        json={"status": "active"},
    )
    assert response.status_code == 200
    assert response.json()["group"]["status"] == "active"


def test_planner_generate_flow_integration(monkeypatch):
    import json
    import sys
    import os

    _ai_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "ai"
    )
    if _ai_path not in sys.path:
        sys.path.insert(0, _ai_path)

    from app.api.routes import planner
    from llm.provider import GenerationResult

    class MockLLMProvider:
        def generate_json(self, messages, model, fallback_model, **kwargs):
            parsed = {
                "items": [
                    {
                        "taskTitle": "Database Project",
                        "courseName": "Database",
                        "suggestedDate": "2026-06-20",
                        "suggestedTime": "10:00-12:00",
                        "hoursNeeded": 2,
                        "priority": "high",
                        "tip": "Review notes first",
                    }
                ],
                "summary": "Focus on the database project first.",
            }
            result = GenerationResult(
                content=json.dumps(parsed),
                model=model,
                provider="groq",
                used_fallback=False,
            )
            return parsed, result

    monkeypatch.setattr(planner, "_llm_provider", MockLLMProvider())

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "tasks": [
                {
                    "id": "integration_plan_1",
                    "title": "Database Project",
                    "status": "pending",
                }
            ],
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["studentName"] == "Pakinam"
    assert len(data["items"]) >= 1
