from fastapi import APIRouter, HTTPException, Query

from app.schemas.notification import (
    DeadlineCheckResponse,
    DeadlineReminderSummary,
    DeleteNotificationResponse,
    MarkAllReadResponse,
    NotificationListResponse,
    NotificationMutationResponse,
)
from app.services import deadline_notification_service, notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=NotificationListResponse)
async def get_notifications(userId: str = Query(..., min_length=1)):
    items = notification_service.list_notifications(user_id=userId)
    return NotificationListResponse(
        items=items,
        unreadCount=notification_service.count_unread(userId),
    )


@router.get("/unread", response_model=NotificationListResponse)
async def get_unread_notifications(userId: str = Query(..., min_length=1)):
    items = notification_service.list_notifications(user_id=userId, unread_only=True)
    return NotificationListResponse(
        items=items,
        unreadCount=len(items),
    )


@router.post("/test-deadline-check", response_model=DeadlineCheckResponse)
async def test_deadline_check():
    try:
        result = deadline_notification_service.check_deadline_notifications()
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Deadline notification check failed: {exc}",
        ) from exc

    if not result.get("success", False):
        raise HTTPException(
            status_code=500,
            detail=result.get("errors") or ["Deadline notification check failed"],
        )

    return DeadlineCheckResponse(
        createdCount=result["createdCount"],
        skippedCount=result["skippedCount"],
        scannedTaskCount=result["scannedTaskCount"],
        reminders=[
            DeadlineReminderSummary(**reminder) for reminder in result["reminders"]
        ],
        errors=result.get("errors", []),
    )


@router.patch("/read-all", response_model=MarkAllReadResponse)
async def mark_all_notifications_read(userId: str = Query(..., min_length=1)):
    updated_count = notification_service.mark_all_notifications_read(userId)
    return MarkAllReadResponse(updatedCount=updated_count, unreadCount=0)


@router.patch("/{notification_id}/read", response_model=NotificationMutationResponse)
async def mark_notification_read(
    notification_id: str,
    userId: str = Query(..., min_length=1),
):
    notification = notification_service.mark_notification_read(notification_id, userId)
    return NotificationMutationResponse(
        notification=notification,
        unreadCount=notification_service.count_unread(userId),
    )


@router.delete("/{notification_id}", response_model=DeleteNotificationResponse)
async def delete_notification(
    notification_id: str,
    userId: str = Query(..., min_length=1),
):
    deleted_id = notification_service.delete_notification(notification_id, userId)
    return DeleteNotificationResponse(
        deletedId=deleted_id,
        unreadCount=notification_service.count_unread(userId),
    )
