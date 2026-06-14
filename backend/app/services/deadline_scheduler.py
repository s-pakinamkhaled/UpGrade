import logging
import threading
from typing import Optional

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger

from app.services.deadline_notification_service import check_deadline_notifications

logger = logging.getLogger(__name__)

JOB_ID = "deadline_notification_check"
CHECK_INTERVAL_HOURS = 1

_scheduler: Optional[BackgroundScheduler] = None
_scheduler_lock = threading.Lock()
_job_lock = threading.Lock()


def _run_deadline_check_job() -> None:
    if not _job_lock.acquire(blocking=False):
        logger.warning(
            "[Scheduler] Deadline check already running; skipping overlapping execution"
        )
        return

    try:
        logger.info("[Scheduler] Deadline check started")
        result = check_deadline_notifications()
        created_count = int(result.get("createdCount", 0))
        errors = result.get("errors") or []

        logger.info("[Scheduler] Deadline check finished")
        logger.info("[Scheduler] Created %s notifications", created_count)
        logger.info("[Scheduler] Errors: %s", len(errors))

        for error in errors:
            logger.error("[Scheduler] %s", error)
    except Exception:
        logger.exception("[Scheduler] Deadline check failed")
    finally:
        _job_lock.release()


def get_scheduler() -> BackgroundScheduler:
    global _scheduler

    if _scheduler is None:
        with _scheduler_lock:
            if _scheduler is None:
                _scheduler = BackgroundScheduler(
                    job_defaults={
                        "coalesce": True,
                        "max_instances": 1,
                    }
                )
    return _scheduler


def is_scheduler_running() -> bool:
    scheduler = _scheduler
    return scheduler is not None and scheduler.running


def start_deadline_scheduler() -> None:
    scheduler = get_scheduler()

    if scheduler.running:
        logger.info("[Scheduler] Deadline scheduler is already running")
        return

    scheduler.add_job(
        _run_deadline_check_job,
        trigger=IntervalTrigger(hours=CHECK_INTERVAL_HOURS),
        id=JOB_ID,
        replace_existing=True,
        max_instances=1,
    )
    scheduler.start()
    logger.info(
        "[Scheduler] Started deadline notification job (interval: %s hour)",
        CHECK_INTERVAL_HOURS,
    )


def shutdown_deadline_scheduler() -> None:
    global _scheduler

    scheduler = _scheduler
    if scheduler is None or not scheduler.running:
        logger.info("[Scheduler] Deadline scheduler is not running")
        return

    try:
        scheduler.shutdown(wait=False)
        logger.info("[Scheduler] Scheduler shut down")
    except Exception:
        logger.exception("[Scheduler] Failed to shut down scheduler")
    finally:
        with _scheduler_lock:
            _scheduler = None
