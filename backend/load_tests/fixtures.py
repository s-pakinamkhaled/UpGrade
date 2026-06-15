"""Shared payloads for Locust performance scenarios."""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta


def new_user_id(prefix: str = "locust") -> str:
    return f"{prefix}_{uuid.uuid4().hex[:12]}"


def new_task_id(prefix: str = "task") -> str:
    return f"{prefix}_{uuid.uuid4().hex[:10]}"


def sample_task_payload(user_id: str, task_id: str | None = None) -> dict:
    now = datetime.utcnow().isoformat()
    return {
        "id": task_id or new_task_id(),
        "userId": user_id,
        "title": "Database Normalization HW",
        "status": "pending",
        "updatedAt": now,
    }


def sample_tasks_for_planner() -> list[dict]:
    deadline = (datetime.utcnow() + timedelta(days=3)).isoformat()
    return [
        {
            "id": new_task_id("plan"),
            "title": "Normalization Assignment",
            "courseName": "Database Systems",
            "deadline": deadline,
            "estimatedMinutes": 120,
            "priority": "high",
            "status": "pending",
        },
        {
            "id": new_task_id("plan"),
            "title": "Graph Algorithms Lab",
            "courseName": "Algorithms",
            "deadline": deadline,
            "estimatedMinutes": 90,
            "priority": "medium",
            "status": "pending",
        },
    ]


def sample_chat_payload(student_name: str = "Locust Student") -> dict:
    return {
        "message": "What should I study now?",
        "conversation_history": [
            {"role": "assistant", "content": f"Hi {student_name}!"},
        ],
        "student_context": {
            "name": student_name,
            "tasks": [
                {
                    "title": "Database Normalization HW",
                    "courseName": "Database Systems",
                    "priority": "high",
                    "status": "pending",
                    "deadline": datetime.utcnow().isoformat(),
                    "estimatedMinutes": 120,
                }
            ],
        },
    }


def sample_study_group_suggestion(user_id: str) -> dict:
    start = datetime.utcnow().replace(hour=18, minute=0, second=0, microsecond=0)
    end = start + timedelta(hours=3)
    return {
        "creatorId": user_id,
        "creatorName": "Locust User",
        "courseId": "cs101",
        "courseName": "Database Systems",
        "goal": "Prepare for midterm",
        "preferredMeetingTime": "18:00",
        "availableStart": start.isoformat(),
        "availableEnd": end.isoformat(),
        "topic": "Normalization",
    }


def sample_profile_update() -> dict:
    return {
        "fullName": "Locust Test User",
        "email": f"{uuid.uuid4().hex[:8]}@loadtest.local",
        "major": "Computer Science",
        "academicYear": "Junior",
        "gpa": "3.50",
    }
