"""
Classroom synchronization service.
"""
import httpx
from typing import List, Dict, Any
from sqlalchemy.orm import Session
from app.models.course import Course
from app.core.config import settings

async def sync_classroom_courses(user_id: int, db: Session) -> List[Course]:
    """
    Sync courses from external classroom system.
    
    Args:
        user_id: ID of the user
        db: Database session
    
    Returns:
        List of synced courses
    """
    if not settings.classroom_api_key:
        # Mock data for development
        return []
    
    try:
        async with httpx.AsyncClient() as client:
            headers = {"Authorization": f"Bearer {settings.classroom_api_key}"}
            response = await client.get(
                "https://classroom.googleapis.com/v1/courses",
                headers=headers
            )
            response.raise_for_status()
            courses_data = response.json().get("courses", [])
            
            synced_courses = []
            for course_data in courses_data:
                # Check if course already exists
                existing = db.query(Course).filter(
                    Course.classroom_id == course_data["id"],
                    Course.user_id == user_id
                ).first()
                
                if not existing:
                    course = Course(
                        name=course_data.get("name", ""),
                        code=course_data.get("courseCode", ""),
                        classroom_id=course_data["id"],
                        user_id=user_id
                    )
                    db.add(course)
                    synced_courses.append(course)
                else:
                    synced_courses.append(existing)
            
            db.commit()
            return synced_courses
    except Exception as e:
        db.rollback()
        raise e

