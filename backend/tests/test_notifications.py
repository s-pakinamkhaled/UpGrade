import sys
import os

sys.path.append(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

from fastapi.testclient import TestClient
from app.main import app
from app.api.routes.notifications import (
    send_course_room_invites,
    CourseInviteEmailRequest,
)

client = TestClient(app)


def test_empty_recipient_list():
    response = client.post(
        "/api/notifications/course-room-invite",
        json={
            "recipientEmails": [],
            "courseName": "AI",
            "inviterName": "Pakinam",
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["sent"] == 0


def test_blank_email_list():
    response = client.post(
        "/api/notifications/course-room-invite",
        json={
            "recipientEmails": ["", "   "],
            "courseName": "AI",
            "inviterName": "Pakinam",
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["sent"] == 0


def test_missing_smtp_configuration():
    old_host = os.environ.pop("SMTP_HOST", None)

    try:
        response = client.post(
            "/api/notifications/course-room-invite",
            json={
                "recipientEmails": ["test@test.com"],
                "courseName": "AI",
                "inviterName": "Pakinam",
            },
        )

        assert response.status_code == 503

    finally:
        if old_host:
            os.environ["SMTP_HOST"] = old_host


def test_missing_smtp_config(monkeypatch):
    monkeypatch.delenv("SMTP_HOST", raising=False)
    monkeypatch.delenv("SMTP_USER", raising=False)
    monkeypatch.delenv("SMTP_PASSWORD", raising=False)

    request = CourseInviteEmailRequest(
        recipientEmails=["test@test.com"],
        courseName="AI",
        inviterName="Pakinam",
    )

    try:
        send_course_room_invites(request)
        assert False
    except Exception:
        assert True


class MockSMTP:
    def __init__(self, *args, **kwargs):
        pass

    def starttls(self):
        pass

    def login(self, *args):
        pass

    def send_message(self, *args):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass


def test_send_email_success(monkeypatch):
    monkeypatch.setenv("SMTP_HOST", "smtp.test.com")
    monkeypatch.setenv("SMTP_USER", "user")
    monkeypatch.setenv("SMTP_PASSWORD", "pass")
    monkeypatch.setenv("SMTP_FROM", "from@test.com")

    import smtplib

    monkeypatch.setattr(
        smtplib,
        "SMTP",
        MockSMTP,
    )

    request = CourseInviteEmailRequest(
        recipientEmails=["a@test.com"],
        courseName="AI",
        inviterName="Pakinam",
    )

    result = send_course_room_invites(request)

    assert result["sent"] == 1


class BrokenSMTP:
    def __init__(self, *args, **kwargs):
        pass

    def __enter__(self):
        raise Exception("SMTP Failed")

    def __exit__(self, *args):
        pass


def test_send_email_failure(monkeypatch):
    monkeypatch.setenv("SMTP_HOST", "smtp.test.com")
    monkeypatch.setenv("SMTP_USER", "user")
    monkeypatch.setenv("SMTP_PASSWORD", "pass")
    monkeypatch.setenv("SMTP_FROM", "from@test.com")

    import smtplib

    monkeypatch.setattr(
        smtplib,
        "SMTP",
        BrokenSMTP,
    )

    request = CourseInviteEmailRequest(
        recipientEmails=["a@test.com"],
        courseName="AI",
        inviterName="Pakinam",
    )

    result = send_course_room_invites(request)

    assert len(result["failed"]) == 1
