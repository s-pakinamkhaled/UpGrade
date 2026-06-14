import sys
import os

sys.path.append(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_get_invalid_task():
    response = client.get("/api/tasks/not_found")

    assert response.status_code == 404


def test_get_activity_logs():
    response = client.get("/api/tasks/activity/logs")

    assert response.status_code == 200

    data = response.json()

    assert data["success"] is True
