import os
import smtplib
from email.message import EmailMessage
from typing import List

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.core.security_utils import filter_invite_emails, sanitize_display_text

router = APIRouter(prefix="/notifications", tags=["notifications"])


class CourseInviteEmailRequest(BaseModel):
    recipientEmails: List[str]
    courseName: str
    inviterName: str
    appUrl: str = "http://localhost:5750/#/home"


@router.post("/course-room-invite")
def send_course_room_invites(request: CourseInviteEmailRequest):
    emails = filter_invite_emails(request.recipientEmails)
    if not emails:
        return {"sent": 0, "skipped": 0, "message": "No valid recipient emails."}

    course_name = sanitize_display_text(request.courseName)
    inviter_name = sanitize_display_text(request.inviterName)

    smtp_host = os.getenv("SMTP_HOST")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_user = os.getenv("SMTP_USER")
    smtp_password = os.getenv("SMTP_PASSWORD")
    smtp_from = os.getenv("SMTP_FROM") or smtp_user

    if not smtp_host or not smtp_user or not smtp_password or not smtp_from:
        raise HTTPException(
            status_code=503,
            detail=(
                "Email service is not configured. Set SMTP_HOST, SMTP_PORT, "
                "SMTP_USER, SMTP_PASSWORD, and SMTP_FROM in backend/.env"
            ),
        )

    sent = 0
    failed = []
    for recipient in emails:
        try:
            msg = EmailMessage()
            msg["Subject"] = f"Study room invite: {course_name}"
            msg["From"] = smtp_from
            msg["To"] = recipient
            msg.set_content(
                f"Hi,\n\n"
                f"{inviter_name} invited you to join a study room for {course_name}.\n"
                f"Open UpGrade and go to Group Study > Incoming Invitations.\n\n"
                f"Open app: {request.appUrl}\n\n"
                f"Best,\nUpGrade Team"
            )

            with smtplib.SMTP(smtp_host, smtp_port, timeout=20) as server:
                server.starttls()
                server.login(smtp_user, smtp_password)
                server.send_message(msg)
            sent += 1
        except Exception:
            failed.append(recipient)

    return {
        "sent": sent,
        "failed": failed,
        "total": len(emails),
    }
