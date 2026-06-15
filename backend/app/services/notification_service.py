import os
import sqlite3
import uuid
from datetime import datetime
from typing import List, Optional

from fastapi import HTTPException

from app.schemas.notification import NotificationRecord

_DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data")
_DB_FILE = os.path.join(_DATA_DIR, "tasks_tracking.db")


def _connect_db() -> sqlite3.Connection:
    conn = sqlite3.connect(_DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn


def ensure_notifications_table() -> None:
    os.makedirs(_DATA_DIR, exist_ok=True)
    with _connect_db() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS notifications (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                title TEXT NOT NULL,
                message TEXT NOT NULL,
                type TEXT NOT NULL,
                is_read INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.commit()


def _row_to_record(row: sqlite3.Row) -> NotificationRecord:
    return NotificationRecord(
        id=row["id"],
        userId=row["user_id"],
        title=row["title"],
        message=row["message"],
        type=row["type"],
        isRead=bool(row["is_read"]),
        createdAt=datetime.fromisoformat(row["created_at"]),
    )


def count_unread(user_id: str) -> int:
    ensure_notifications_table()
    with _connect_db() as conn:
        row = conn.execute(
            """
            SELECT COUNT(*) AS total
            FROM notifications
            WHERE user_id = ? AND is_read = 0
            """,
            (user_id,),
        ).fetchone()
    return int(row["total"])


def list_notifications(user_id: str, unread_only: bool = False) -> List[NotificationRecord]:
    ensure_notifications_table()
    query = """
        SELECT id, user_id, title, message, type, is_read, created_at
        FROM notifications
        WHERE user_id = ?
    """
    params: tuple = (user_id,)
    if unread_only:
        query += " AND is_read = 0"
    query += " ORDER BY created_at DESC"

    with _connect_db() as conn:
        rows = conn.execute(query, params).fetchall()
    return [_row_to_record(row) for row in rows]


def get_notification(notification_id: str, user_id: str) -> NotificationRecord:
    ensure_notifications_table()
    with _connect_db() as conn:
        row = conn.execute(
            """
            SELECT id, user_id, title, message, type, is_read, created_at
            FROM notifications
            WHERE id = ? AND user_id = ?
            """,
            (notification_id, user_id),
        ).fetchone()

    if row is None:
        raise HTTPException(status_code=404, detail=f"Notification {notification_id} not found")
    return _row_to_record(row)


def notification_exists(notification_id: str) -> bool:
    ensure_notifications_table()
    with _connect_db() as conn:
        row = conn.execute(
            "SELECT 1 FROM notifications WHERE id = ? LIMIT 1",
            (notification_id,),
        ).fetchone()
    return row is not None


def create_notification_if_not_exists(
    user_id: str,
    title: str,
    message: str,
    notification_type: str,
    notification_id: str,
) -> tuple[Optional[NotificationRecord], bool]:
    if notification_exists(notification_id):
        return None, False
    record = create_notification(
        user_id=user_id,
        title=title,
        message=message,
        notification_type=notification_type,
        notification_id=notification_id,
    )
    return record, True


def create_notification(
    user_id: str,
    title: str,
    message: str,
    notification_type: str,
    notification_id: Optional[str] = None,
) -> NotificationRecord:
    ensure_notifications_table()
    record_id = notification_id or str(uuid.uuid4())
    created_at = datetime.utcnow().isoformat()

    with _connect_db() as conn:
        conn.execute(
            """
            INSERT INTO notifications (
                id, user_id, title, message, type, is_read, created_at
            ) VALUES (?, ?, ?, ?, ?, 0, ?)
            """,
            (record_id, user_id, title, message, notification_type, created_at),
        )
        conn.commit()

    return NotificationRecord(
        id=record_id,
        userId=user_id,
        title=title,
        message=message,
        type=notification_type,
        isRead=False,
        createdAt=datetime.fromisoformat(created_at),
    )


def mark_notification_read(notification_id: str, user_id: str) -> NotificationRecord:
    ensure_notifications_table()
    existing = get_notification(notification_id, user_id)

    with _connect_db() as conn:
        conn.execute(
            """
            UPDATE notifications
            SET is_read = 1
            WHERE id = ? AND user_id = ?
            """,
            (notification_id, user_id),
        )
        conn.commit()

    existing.isRead = True
    return existing


def mark_all_notifications_read(user_id: str) -> int:
    ensure_notifications_table()
    with _connect_db() as conn:
        cursor = conn.execute(
            """
            UPDATE notifications
            SET is_read = 1
            WHERE user_id = ? AND is_read = 0
            """,
            (user_id,),
        )
        conn.commit()
        return cursor.rowcount


def delete_notification(notification_id: str, user_id: str) -> str:
    ensure_notifications_table()
    get_notification(notification_id, user_id)

    with _connect_db() as conn:
        conn.execute(
            """
            DELETE FROM notifications
            WHERE id = ? AND user_id = ?
            """,
            (notification_id, user_id),
        )
        conn.commit()

    return notification_id
