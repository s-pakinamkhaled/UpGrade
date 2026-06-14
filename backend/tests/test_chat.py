import sys
import os

sys.path.append(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_chat_health():
    response = client.get("/api/chat/health")

    assert response.status_code == 200


def test_chat_suggestions():
    response = client.get("/api/chat/suggestions")

    assert response.status_code == 200

    data = response.json()

    assert "suggestions" in data


def test_chat_suggestions_with_flags():
    response = client.get(
        "/api/chat/suggestions?has_urgent_tasks=true&has_upcoming_deadline=true"
    )

    assert response.status_code == 200

    data = response.json()

    assert "suggestions" in data
