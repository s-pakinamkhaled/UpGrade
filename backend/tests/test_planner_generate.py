"""
Tests for POST /api/plan/generate endpoint.

Updated to patch `_llm_provider` (LLMProvider) instead of the old `groq_client`.
The endpoint contract (request schema, response schema) is unchanged.
"""
import sys
import os
import json

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from app.main import app
from app.api.routes import planner

client = TestClient(app)

_AI_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "ai"
)
if _AI_PATH not in sys.path:
    sys.path.insert(0, _AI_PATH)

from llm.provider import GenerationResult


def _make_provider_mock(items, summary="Test summary", raise_error=False, bad_json=False):
    """Return a mock LLMProvider whose generate_json() returns canned data."""

    class _MockProvider:
        def generate_json(self, messages, model, fallback_model, **kwargs):
            if raise_error:
                raise RuntimeError("All models failed")
            if bad_json:
                raise json.JSONDecodeError("bad json", "", 0)
            parsed = {"items": items, "summary": summary}
            result = GenerationResult(
                content=json.dumps(parsed),
                model=model,
                provider="groq",
                used_fallback=False,
            )
            return parsed, result

    return _MockProvider()


def test_generate_plan_success(monkeypatch):
    mock_items = [
        {
            "taskTitle": "AI Assignment",
            "courseName": "AI",
            "suggestedDate": "2026-06-20",
            "suggestedTime": "10:00-12:00",
            "hoursNeeded": 2,
            "priority": "high",
            "tip": "Start early",
        }
    ]
    monkeypatch.setattr(planner, "_llm_provider", _make_provider_mock(mock_items))

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "tasks": [{"id": "1", "title": "AI Assignment", "status": "pending"}],
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True


def test_generate_plan_invalid_json(monkeypatch):
    monkeypatch.setattr(planner, "_llm_provider", _make_provider_mock([], bad_json=True))

    response = client.post(
        "/api/plan/generate",
        json={"studentName": "Pakinam", "tasks": [{"id": "1", "title": "Task"}]},
    )

    assert response.status_code == 502


def test_generate_plan_groq_error(monkeypatch):
    monkeypatch.setattr(planner, "_llm_provider", _make_provider_mock([], raise_error=True))

    response = client.post(
        "/api/plan/generate",
        json={"studentName": "Pakinam", "tasks": [{"id": "1", "title": "Task"}]},
    )

    assert response.status_code == 502
