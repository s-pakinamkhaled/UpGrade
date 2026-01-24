"""
Task Pydantic schemas.
"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class TaskBase(BaseModel):
    title: str
    description: Optional[str] = None
    due_date: Optional[datetime] = None
    priority: int = 0
    estimated_hours: Optional[float] = None

class TaskCreate(TaskBase):
    course_id: Optional[int] = None

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    due_date: Optional[datetime] = None
    priority: Optional[int] = None
    status: Optional[str] = None
    estimated_hours: Optional[float] = None
    actual_hours: Optional[float] = None
    risk_score: Optional[float] = None

class TaskResponse(TaskBase):
    id: int
    status: str
    risk_score: Optional[float] = None
    owner_id: int
    course_id: Optional[int] = None
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

