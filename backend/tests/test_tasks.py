import sys
import os

sys.path.append(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

from datetime import datetime
from fastapi import HTTPException

from app.api.routes.tasks import (
    TaskRecord,
    UpdateTaskStatusRequest,
    StudyActivityLog,
)


def test_task_model_creation():
    task = TaskRecord(
        id="1",
        userId="student1",
        title="Study AI",
        status="pending",
        updatedAt=datetime.utcnow(),
    )

    assert task.id == "1"
    assert task.userId == "student1"
    assert task.status == "pending"


def test_update_task_request_model():
    request = UpdateTaskStatusRequest(
        status="inProgress",
        userId="student1",
    )

    assert request.status == "inProgress"
    assert request.userId == "student1"


def test_activity_log_model():
    log = StudyActivityLog(
        taskId="1",
        userId="student1",
        action="started",
        timestamp=datetime.utcnow(),
    )

    assert log.taskId == "1"
    assert log.action == "started"


def test_task_default_status():
    task = TaskRecord(
        id="2",
        userId="student2",
        updatedAt=datetime.utcnow(),
    )

    assert task.status == "pending"
