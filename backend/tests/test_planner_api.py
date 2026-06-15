import sys
import os

sys.path.append(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_generate_plan_empty_tasks():
    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "tasks": [],
        },
    )

    assert response.status_code == 400


def test_planner_health():
    response = client.get("/api/plan/health")

    assert response.status_code == 200

    data = response.json()

    assert "status" in data


def test_generate_plan_completed_tasks_only():
    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "tasks": [
                {
                    "id": "1",
                    "title": "Finished Task",
                    "status": "completed",
                }
            ],
        },
    )

    assert response.status_code in [400, 503]
