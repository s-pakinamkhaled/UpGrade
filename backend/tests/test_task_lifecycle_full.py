import sys
import os

sys.path.append(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

from datetime import datetime
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_full_task_lifecycle():
    task = {
        "id": "life_task",
        "userId": "student1",
        "title": "OS Project",
        "status": "pending",
        "updatedAt": datetime.utcnow().isoformat(),
    }

    r = client.post("/api/tasks", json=task)
    assert r.status_code == 200

    r = client.get("/api/tasks/life_task")
    assert r.status_code == 200

    r = client.patch(
        "/api/tasks/life_task/status",
        json={
            "status": "inProgress",
            "userId": "student1",
        },
    )
    assert r.status_code == 200

    r = client.patch(
        "/api/tasks/life_task/status",
        json={
            "status": "completed",
            "userId": "student1",
        },
    )
    assert r.status_code == 200

    r = client.patch(
        "/api/tasks/life_task/status",
        json={
            "status": "pending",
            "userId": "student1",
        },
    )
    assert r.status_code == 200

    r = client.get("/api/tasks/activity/logs")
    assert r.status_code == 200

    data = r.json()

    assert data["success"] is True
