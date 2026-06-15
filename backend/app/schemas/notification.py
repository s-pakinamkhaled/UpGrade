from datetime import datetime
from typing import List

from pydantic import BaseModel, Field


class NotificationRecord(BaseModel):
    id: str
    userId: str
    title: str
    message: str
    type: str
    isRead: bool = False
    createdAt: datetime


class NotificationListResponse(BaseModel):
    success: bool = True
    items: List[NotificationRecord]
    unreadCount: int


class NotificationMutationResponse(BaseModel):
    success: bool = True
    notification: NotificationRecord | None = None
    unreadCount: int


class MarkAllReadResponse(BaseModel):
    success: bool = True
    updatedCount: int
    unreadCount: int = 0


class DeleteNotificationResponse(BaseModel):
    success: bool = True
    deletedId: str
    unreadCount: int


class DeadlineReminderSummary(BaseModel):
    taskId: str
    taskTitle: str
    userId: str
    reminderType: str
    notificationId: str
    title: str
    message: str
    type: str


class DeadlineCheckResponse(BaseModel):
    success: bool = True
    createdCount: int
    skippedCount: int
    scannedTaskCount: int
    reminders: List[DeadlineReminderSummary]
    errors: List[str] = []
