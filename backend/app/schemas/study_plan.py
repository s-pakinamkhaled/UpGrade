"""
Study Plan Pydantic schemas.
"""
from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime

class StudyPlanBase(BaseModel):
    name: str
    start_date: datetime
    end_date: datetime

class StudyPlanCreate(StudyPlanBase):
    course_id: Optional[int] = None

class StudyPlanUpdate(BaseModel):
    name: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    schedule: Optional[Dict[str, Any]] = None

class StudyPlanResponse(StudyPlanBase):
    id: int
    schedule: Optional[Dict[str, Any]] = None
    user_id: int
    course_id: Optional[int] = None
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

