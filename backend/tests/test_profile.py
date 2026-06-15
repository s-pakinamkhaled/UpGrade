import sys
import os

sys.path.append(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

from fastapi.testclient import TestClient

from app.api.routes.profile import (
    ProfileRecord,
    UpdateProfileRequest,
    _default_profile,
)
from app.main import app

client = TestClient(app)


def test_profile_record_defaults():
    record = ProfileRecord(
        userId="u1",
        fullName="Pakinam",
        email="pakinam@test.com",
        updatedAt="2025-01-01T00:00:00",
    )

    assert record.major == "Computer Science"
    assert record.academicYear == "Junior"
    assert record.gpa == "3.85"


def test_update_profile_request_model():
    request = UpdateProfileRequest(
        fullName="Pakinam",
        email="pakinam@test.com",
        major="AI",
    )

    assert request.fullName == "Pakinam"
    assert request.email == "pakinam@test.com"
    assert request.major == "AI"


def test_default_profile():
    profile = _default_profile("student1")

    assert profile["userId"] == "student1"
    assert profile["fullName"] == ""
    assert profile["email"] == ""
    assert profile["major"] == "Computer Science"


def test_get_profile():
    response = client.get("/api/profile/pytest_profile_user_001")

    assert response.status_code == 200

    data = response.json()

    assert data["success"] is True
    assert data["profile"]["userId"] == "pytest_profile_user_001"


def test_update_profile():
    response = client.patch(
        "/api/profile/pytest_profile_user_002",
        json={
            "fullName": "Pakinam",
            "email": "pakinam@test.com",
            "major": "AI",
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["success"] is True
    assert data["profile"]["fullName"] == "Pakinam"
    assert data["profile"]["email"] == "pakinam@test.com"
    assert data["profile"]["major"] == "AI"
