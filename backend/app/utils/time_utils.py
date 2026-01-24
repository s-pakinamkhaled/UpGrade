"""
Time utility functions.
"""
from datetime import datetime, timedelta
from typing import Optional

def parse_datetime(date_string: str) -> Optional[datetime]:
    """Parse a datetime string."""
    try:
        return datetime.fromisoformat(date_string)
    except ValueError:
        return None

def days_until(due_date: datetime) -> int:
    """Calculate days until a due date."""
    delta = due_date - datetime.now()
    return delta.days

def is_overdue(due_date: datetime) -> bool:
    """Check if a due date has passed."""
    return datetime.now() > due_date

def get_week_range(date: datetime = None) -> tuple[datetime, datetime]:
    """Get the start and end of the week for a given date."""
    if date is None:
        date = datetime.now()
    start = date - timedelta(days=date.weekday())
    end = start + timedelta(days=6)
    return start, end

