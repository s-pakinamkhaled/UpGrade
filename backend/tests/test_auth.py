"""
Tests for authentication.
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_register():
    """Test user registration."""
    response = client.post(
        "/auth/register",
        json={
            "email": "test@example.com",
            "password": "testpassword",
            "full_name": "Test User"
        }
    )
    assert response.status_code == 200
    assert "email" in response.json()

def test_login():
    """Test user login."""
    # First register
    client.post(
        "/auth/register",
        json={
            "email": "test2@example.com",
            "password": "testpassword",
            "full_name": "Test User"
        }
    )
    
    # Then login
    response = client.post(
        "/auth/login",
        data={"username": "test2@example.com", "password": "testpassword"}
    )
    assert response.status_code == 200
    assert "access_token" in response.json()

