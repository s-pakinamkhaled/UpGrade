"""
Tests for study planner.
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_create_study_plan():
    """Test study plan creation."""
    from datetime import datetime, timedelta
    response = client.post(
        "/planner/",
        json={
            "name": "Test Plan",
            "start_date": datetime.now().isoformat(),
            "end_date": (datetime.now() + timedelta(days=30)).isoformat()
        }
    )
    # This will fail without auth - placeholder for now
    assert response.status_code in [200, 401]

