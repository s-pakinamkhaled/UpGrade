"""
Background job workers.
"""
from datetime import datetime
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.task import Task
from app.models.user import User
from app.services.risk_service import calculate_risk_scores
from app.services.notification import send_risk_alert

async def update_risk_scores():
    """Background job to update risk scores for all tasks."""
    db: Session = SessionLocal()
    try:
        # Get all active tasks
        tasks = db.query(Task).filter(Task.status != "completed").all()
        
        if tasks:
            # Calculate risk scores
            risk_scores = await calculate_risk_scores(tasks)
            
            # Update tasks
            for task in tasks:
                if task.id in risk_scores:
                    task.risk_score = risk_scores[task.id]
                    db.add(task)
            
            db.commit()
    finally:
        db.close()

async def send_risk_alerts():
    """Background job to send risk alerts for high-risk tasks."""
    db: Session = SessionLocal()
    try:
        # Get high-risk tasks
        tasks = db.query(Task).filter(
            Task.risk_score > 0.7,
            Task.status != "completed"
        ).all()
        
        for task in tasks:
            user = db.query(User).filter(User.id == task.owner_id).first()
            if user:
                await send_risk_alert(task, user, task.risk_score)
    finally:
        db.close()

