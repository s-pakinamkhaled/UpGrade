from datetime import datetime
import os
import sqlite3
from typing import Dict, List, Literal, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.core.security_utils import is_safe_path_segment, sanitize_display_text

TaskStatus = Literal["pending", "inProgress", "completed"]
ActivityAction = Literal["started", "completed", "reopened"]

router = APIRouter(prefix="/tasks", tags=["tasks"])


class TaskRecord(BaseModel):
    id: str
    userId: str
    title: Optional[str] = None
    status: TaskStatus = "pending"
    deadline: Optional[datetime] = None
    startedAt: Optional[datetime] = None
    completedAt: Optional[datetime] = None
    updatedAt: datetime


class UpdateTaskStatusRequest(BaseModel):
    status: TaskStatus
    userId: str = "anonymous"


class StudyActivityLog(BaseModel):
    taskId: str
    userId: str
    action: ActivityAction
    timestamp: datetime


_DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data")
_LEGACY_JSON_FILE = os.path.join(_DATA_DIR, "tasks_tracking.json")
_DB_FILE = os.path.join(_DATA_DIR, "tasks_tracking.db")


def _connect_db() -> sqlite3.Connection:
    conn = sqlite3.connect(_DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn


def _ensure_data_store() -> None:
    os.makedirs(_DATA_DIR, exist_ok=True)
    with _connect_db() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                title TEXT,
                status TEXT NOT NULL,
                started_at TEXT,
                completed_at TEXT,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS activity_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                action TEXT NOT NULL,
                timestamp TEXT NOT NULL
            )
            """
        )
        columns = {
            row[1] for row in conn.execute("PRAGMA table_info(tasks)").fetchall()
        }
        if "deadline" not in columns:
            conn.execute("ALTER TABLE tasks ADD COLUMN deadline TEXT")
        conn.commit()

    _migrate_legacy_json_if_needed()


def _load_store() -> Dict:
    _ensure_data_store()
    with _connect_db() as conn:
        task_rows = conn.execute(
            """
            SELECT id, user_id, title, status, deadline, started_at, completed_at, updated_at
            FROM tasks
            """
        ).fetchall()
        log_rows = conn.execute(
            """
            SELECT task_id, user_id, action, timestamp
            FROM activity_logs
            ORDER BY id ASC
            """
        ).fetchall()

    tasks: Dict[str, Dict] = {}
    for row in task_rows:
        tasks[row["id"]] = {
            "id": row["id"],
            "userId": row["user_id"],
            "title": row["title"],
            "status": row["status"],
            "deadline": row["deadline"],
            "startedAt": row["started_at"],
            "completedAt": row["completed_at"],
            "updatedAt": row["updated_at"],
        }

    activity_logs: List[Dict] = []
    for row in log_rows:
        activity_logs.append(
            {
                "taskId": row["task_id"],
                "userId": row["user_id"],
                "action": row["action"],
                "timestamp": row["timestamp"],
            }
        )

    return {"tasks": tasks, "activityLogs": activity_logs}


def _save_store(data: Dict) -> None:
    _ensure_data_store()
    with _connect_db() as conn:
        conn.execute("DELETE FROM tasks")
        conn.execute("DELETE FROM activity_logs")

        for task in data.get("tasks", {}).values():
            conn.execute(
                """
                INSERT INTO tasks (
                    id, user_id, title, status, deadline, started_at, completed_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    task.get("id"),
                    task.get("userId"),
                    task.get("title"),
                    task.get("status"),
                    task.get("deadline"),
                    task.get("startedAt"),
                    task.get("completedAt"),
                    task.get("updatedAt"),
                ),
            )

        for log in data.get("activityLogs", []):
            conn.execute(
                """
                INSERT INTO activity_logs (task_id, user_id, action, timestamp)
                VALUES (?, ?, ?, ?)
                """,
                (
                    log.get("taskId"),
                    log.get("userId"),
                    log.get("action"),
                    log.get("timestamp"),
                ),
            )
        conn.commit()


def _append_log(data: Dict, task_id: str, user_id: str, action: ActivityAction, now: datetime) -> None:
    data["activityLogs"].append(
        {
            "taskId": task_id,
            "userId": user_id,
            "action": action,
            "timestamp": now.isoformat(),
        }
    )


def _migrate_legacy_json_if_needed() -> None:
    if not os.path.exists(_LEGACY_JSON_FILE):
        return

    with _connect_db() as conn:
        existing_count = conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
        if existing_count > 0:
            return

    try:
        import json

        with open(_LEGACY_JSON_FILE, "r", encoding="utf-8") as f:
            legacy = json.load(f)

        tasks = legacy.get("tasks", {})
        logs = legacy.get("activityLogs", [])
        _save_store({"tasks": tasks, "activityLogs": logs})
    except Exception:
        # Keep startup resilient even if old file is malformed.
        return


def list_all_tasks() -> List[TaskRecord]:
    data = _load_store()
    tasks: List[TaskRecord] = []
    for raw_task in data["tasks"].values():
        try:
            tasks.append(TaskRecord.model_validate(raw_task))
        except Exception:
            continue
    return tasks


def update_task_status(task_id: str, new_status: TaskStatus, user_id: str) -> TaskRecord:
    data = _load_store()
    raw_task = data["tasks"].get(task_id)
    if raw_task is None:
        raise HTTPException(status_code=404, detail=f"Task {task_id} not found")
    task = TaskRecord.model_validate(raw_task)

    now = datetime.utcnow()
    previous_status = task.status

    if new_status == "inProgress":
        task.status = "inProgress"
        if task.startedAt is None:
            task.startedAt = now

    if new_status == "completed":
        task.status = "completed"
        task.completedAt = now

    if new_status == "pending":
        task.status = "pending"
        task.completedAt = None

    task.updatedAt = now
    data["tasks"][task_id] = task.model_dump(mode="json")

    if previous_status != task.status:
        if task.status == "inProgress":
            _append_log(data, task_id, user_id, "started", now)
        elif task.status == "completed":
            _append_log(data, task_id, user_id, "completed", now)
        elif task.status == "pending" and previous_status == "completed":
            _append_log(data, task_id, user_id, "reopened", now)

    _save_store(data)
    return task


@router.patch("/{task_id}/status")
async def patch_task_status(task_id: str, body: UpdateTaskStatusRequest):
    if not is_safe_path_segment(task_id) or not is_safe_path_segment(body.userId):
        raise HTTPException(status_code=400, detail="Invalid task or user id")
    """
    Update task status following F7 rules:
    - pending -> inProgress sets startedAt if empty.
    - pending|inProgress -> completed sets completedAt.
    - completed -> pending clears completedAt.
    Always updates updatedAt and writes a study activity log on actual status changes.
    """
    task = update_task_status(task_id=task_id, new_status=body.status, user_id=body.userId)
    data = _load_store()
    return {"success": True, "task": task.model_dump(mode="json"), "logsCount": len(data["activityLogs"])}


@router.post("")
async def upsert_task(task: TaskRecord):
    if not is_safe_path_segment(task.id) or not is_safe_path_segment(task.userId):
        raise HTTPException(status_code=400, detail="Invalid task or user id")
    payload = task.model_dump(mode="json")
    if payload.get("title"):
        payload["title"] = sanitize_display_text(str(payload["title"]))
    data = _load_store()
    data["tasks"][task.id] = payload
    _save_store(data)
    return {"success": True, "task": payload}


@router.get("/activity/logs")
async def get_activity_logs():
    data = _load_store()
    return {"success": True, "items": data["activityLogs"]}


@router.get("/{task_id}")
async def get_task(task_id: str):
    if not is_safe_path_segment(task_id):
        raise HTTPException(status_code=400, detail="Invalid task id")
    data = _load_store()
    raw_task = data["tasks"].get(task_id)
    if raw_task is None:
        raise HTTPException(status_code=404, detail=f"Task {task_id} not found")
    return {"success": True, "task": raw_task}
