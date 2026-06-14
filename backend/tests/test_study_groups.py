import sys
import os

sys.path.append(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_get_suggestions():
    response = client.get(
        "/api/study-groups/suggestions",
        params={
            "creator_id": "u1",
            "creator_name": "Pakinam",
            "course_id": "cs101",
            "course_name": "Database",
            "goal": "Finish project",
            "preferred_meeting_time": "18:00",
            "available_start": "2026-06-01T18:00:00",
            "available_end": "2026-06-01T21:00:00",
            "topic": "Normalization",
        },
    )

    assert response.status_code == 200


def test_post_suggestions():
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


def test_validation_error_without_topic_or_assignment():
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
        },
    )

    assert response.status_code == 422


def test_my_groups():
    response = client.get(
        "/api/study-groups/my-groups",
        params={
            "userId": "u1",
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert "groups" in data


def test_update_missing_group():
    response = client.patch(
        "/api/study-groups/not_found/status",
        json={
            "status": "active",
        },
    )

    assert response.status_code == 404
