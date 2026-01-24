"""
Classroom integration routes.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.course import Course
from app.services.classroom_sync import sync_classroom_courses

router = APIRouter(prefix="/classroom", tags=["classroom"])

@router.get("/courses")
async def get_courses(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all courses for the current user."""
    courses = db.query(Course).filter(Course.user_id == current_user.id).all()
    return courses

@router.post("/sync")
async def sync_courses(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Sync courses from external classroom system."""
    try:
        synced_courses = await sync_classroom_courses(current_user.id, db)
        return {"message": f"Synced {len(synced_courses)} courses", "courses": synced_courses}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

