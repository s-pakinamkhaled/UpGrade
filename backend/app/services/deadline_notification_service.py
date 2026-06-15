import logging
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple

from app.api.routes.tasks import TaskRecord, list_all_tasks
from app.services import notification_service

logger = logging.getLogger(__name__)

REMINDER_3D = "3d"
REMINDER_24H = "24h"
REMINDER_6H = "6h"
REMINDER_OVERDUE = "overdue"

UPCOMING_TITLE = "Upcoming Deadline"
OVERDUE_TITLE = "Overdue Task"


def _notification_id(task_id: str, reminder_kind: str) -> str:
    return f"deadline_{task_id}_{reminder_kind}"


def _parse_deadline(value: Optional[datetime]) -> Optional[datetime]:
    if value is None:
        return None
    if value.tzinfo is not None:
        return value.replace(tzinfo=None)
    return value


def _task_title(task: TaskRecord) -> str:
    title = (task.title or "").strip()
    return title if title else "Untitled task"


def _is_completed(task: TaskRecord) -> bool:
    return task.status == "completed"


def check_deadline_notifications() -> Dict[str, Any]:
    now = datetime.utcnow()
    scanned_task_count = 0
    created_count = 0
    skipped_count = 0
    reminders: List[Dict[str, Any]] = []
    errors: List[str] = []

    try:
        tasks = list_all_tasks()
    except Exception as exc:
        logger.exception("Failed to load tasks for deadline notification check")
        return {
            "success": False,
            "createdCount": 0,
            "skippedCount": 0,
            "scannedTaskCount": 0,
            "reminders": [],
            "errors": [f"Failed to load tasks: {exc}"],
        }

    for task in tasks:
        scanned_task_count += 1
        try:
            created, skipped, task_reminders = _process_task(task, now)
            created_count += created
            skipped_count += skipped
            reminders.extend(task_reminders)
        except Exception as exc:
            logger.exception(
                "Failed to process deadline reminders for task %s", task.id
            )
            errors.append(f"Task {task.id}: {exc}")

    logger.info(
        "Deadline notification check finished: scanned=%s created=%s skipped=%s",
        scanned_task_count,
        created_count,
        skipped_count,
    )

    return {
        "success": True,
        "createdCount": created_count,
        "skippedCount": skipped_count,
        "scannedTaskCount": scanned_task_count,
        "reminders": reminders,
        "errors": errors,
    }


def _process_task(
    task: TaskRecord,
    now: datetime,
) -> Tuple[int, int, List[Dict[str, Any]]]:
    created_count = 0
    skipped_count = 0
    reminders: List[Dict[str, Any]] = []

    if _is_completed(task):
        return created_count, skipped_count, reminders

    deadline = _parse_deadline(task.deadline)
    if deadline is None:
        return created_count, skipped_count, reminders

    title = _task_title(task)
    time_until = deadline - now

    if time_until.total_seconds() <= 0:
        created, skipped, reminder = _create_reminder_if_needed(
            task=task,
            reminder_kind=REMINDER_OVERDUE,
            notification_title=OVERDUE_TITLE,
            message=f"{title} is overdue.",
            notification_type="deadline_overdue",
        )
        created_count += created
        skipped_count += skipped
        if reminder:
            reminders.append(reminder)
        return created_count, skipped_count, reminders

    upcoming_rules = [
        (
            REMINDER_3D,
            timedelta(days=3),
            "is due in 3 days.",
            "deadline_3d",
        ),
        (
            REMINDER_24H,
            timedelta(hours=24),
            "is due in 24 hours.",
            "deadline_24h",
        ),
        (
            REMINDER_6H,
            timedelta(hours=6),
            "is due in 6 hours.",
            "deadline_6h",
        ),
    ]

    for reminder_kind, threshold, message_suffix, notification_type in upcoming_rules:
        if time_until > threshold:
            continue

        created, skipped, reminder = _create_reminder_if_needed(
            task=task,
            reminder_kind=reminder_kind,
            notification_title=UPCOMING_TITLE,
            message=f"{title} {message_suffix}",
            notification_type=notification_type,
        )
        created_count += created
        skipped_count += skipped
        if reminder:
            reminders.append(reminder)

    return created_count, skipped_count, reminders


def _create_reminder_if_needed(
    task: TaskRecord,
    reminder_kind: str,
    notification_title: str,
    message: str,
    notification_type: str,
) -> Tuple[int, int, Optional[Dict[str, Any]]]:
    notification_id = _notification_id(task.id, reminder_kind)
    record, created = notification_service.create_notification_if_not_exists(
        user_id=task.userId,
        title=notification_title,
        message=message,
        notification_type=notification_type,
        notification_id=notification_id,
    )

    if not created:
        logger.debug(
            "Skipped duplicate deadline reminder %s for task %s",
            reminder_kind,
            task.id,
        )
        return 0, 1, None

    logger.info(
        "Created deadline reminder %s for task %s (notification %s)",
        reminder_kind,
        task.id,
        notification_id,
    )
    return 1, 0, {
        "taskId": task.id,
        "taskTitle": _task_title(task),
        "userId": task.userId,
        "reminderType": reminder_kind,
        "notificationId": notification_id,
        "title": notification_title,
        "message": message,
        "type": notification_type,
    }
