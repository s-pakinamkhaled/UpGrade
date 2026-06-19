import sys
import os
import json
from datetime import datetime, timedelta

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from app.main import app
from app.api.routes import planner
from app.api.routes.planner import PlanRequest, TaskInput, _build_prompt, _PRIORITY_RANK

client = TestClient(app)

_AI_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "ai"
)
if _AI_PATH not in sys.path:
    sys.path.insert(0, _AI_PATH)

from llm.provider import GenerationResult


def _mock_provider_with_items(items, summary="Plan ready.", prompt_check_fn=None):
    """Return a LLMProvider mock whose generate_json returns the given items."""

    class _MockProvider:
        def generate_json(self, messages, model, fallback_model, **kwargs):
            if prompt_check_fn:
                prompt_check_fn(messages)
            parsed = {"items": items, "summary": summary}
            result = GenerationResult(
                content=json.dumps(parsed),
                model=model,
                provider="groq",
                used_fallback=False,
            )
            return parsed, result

    return _MockProvider()


def _mock_provider_with_tip_completion(initial_items, tip_items):
    class _MockProvider:
        def __init__(self):
            self.calls = 0

        def generate_json(self, messages, model, fallback_model, **kwargs):
            self.calls += 1
            parsed = (
                {"items": initial_items, "summary": "Initial plan."}
                if self.calls == 1
                else {"items": tip_items}
            )
            result = GenerationResult(
                content=json.dumps(parsed),
                model=model,
                provider="groq",
                used_fallback=False,
            )
            return parsed, result

    return _MockProvider()


def test_priority_rank_order():
    assert _PRIORITY_RANK["urgent"] < _PRIORITY_RANK["high"]
    assert _PRIORITY_RANK["high"] < _PRIORITY_RANK["medium"]


def test_build_prompt_includes_grade_info():
    request = PlanRequest(
        studentName="Student",
        tasks=[
            TaskInput(
                id="1",
                title="Database Report",
                assignedGrade=18.0,
                maxPoints=20,
            )
        ],
    )

    prompt = _build_prompt(request)

    assert "Grade: 18.0/20" in prompt


def test_build_prompt_treats_estimates_as_capacity_source():
    request = PlanRequest(
        studentName="Student",
        defaultDailyHours=6,
        tasks=[
            TaskInput(
                id="1",
                title="Final Submission",
                estimatedMinutes=120,
            )
        ],
    )

    prompt = _build_prompt(request)

    assert "hoursNeeded exactly (120 min = 2h" in prompt
    assert "field must equal Est minutes divided by 60" in prompt


def test_generate_plan_filters_grade_and_lab_tasks(monkeypatch):
    def _check_prompt(messages):
        user_content = messages[-1]["content"]
        assert "Midterm Grades" not in user_content
        assert "Lab08" not in user_content
        assert "Normalization HW" in user_content

    items = [
        {
            "taskTitle": "Normalization HW",
            "courseName": "Database",
            "suggestedDate": "2026-06-15",
            "suggestedTime": "14:00 – 16:00",
            "hoursNeeded": 2,
            "priority": "high",
            "tip": "Start with examples",
        }
    ]
    monkeypatch.setattr(
        planner,
        "_llm_provider",
        _mock_provider_with_items(items, summary="One task plan.", prompt_check_fn=_check_prompt),
    )

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "tasks": [
                {"id": "1", "title": "Normalization HW", "status": "pending", "priority": "high"},
                {"id": "2", "title": "Midterm Grades", "status": "pending"},
                {"id": "3", "title": "Lab08 - Lab task", "status": "pending"},
                {"id": "4", "title": "Finished Essay", "status": "completed"},
            ],
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["items"][0]["taskTitle"] == "Normalization HW"


def test_generate_plan_strips_markdown_fences(monkeypatch):
    # The LLMProvider already strips markdown fences in generate_json, so the
    # planner route receives clean JSON. We test that the route accepts it.
    items = [
        {
            "taskTitle": "AI Assignment",
            "courseName": "AI",
            "suggestedDate": "2026-06-20",
            "suggestedTime": "10:00-12:00",
            "hoursNeeded": 2,
            "priority": "medium",
            "tip": "Review slides",
        }
    ]
    monkeypatch.setattr(planner, "_llm_provider", _mock_provider_with_items(items))

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "tasks": [{"id": "1", "title": "AI Assignment", "status": "pending"}],
        },
    )

    assert response.status_code == 200
    assert response.json()["success"] is True


def test_generate_plan_corrects_llm_hours_and_packs_daily_capacity(monkeypatch):
    today = datetime.now().strftime("%Y-%m-%d")
    deadline = (datetime.now() + timedelta(days=5)).isoformat()
    items = [
        {
            "taskTitle": "Final Submissions",
            "courseName": "Senior Project",
            "suggestedDate": today,
            "suggestedTime": "09:00-13:00",
            # Wrong on purpose: task estimate is 120 min, so backend must return 2h.
            "hoursNeeded": 4,
            "priority": "high",
            "tip": "Finalize the project report and prepare the submission package.",
        }
    ]
    monkeypatch.setattr(planner, "_llm_provider", _mock_provider_with_items(items))

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "defaultDailyHours": 6,
            "dailyHours": [{"date": today, "hours": 6}],
            "tasks": [
                {
                    "id": "1",
                    "title": "Final Submissions",
                    "courseName": "Senior Project",
                    "status": "pending",
                    "estimatedMinutes": 120,
                    "deadline": deadline,
                },
                {
                    "id": "2",
                    "title": "Docker Workflow",
                    "courseName": "Machine Learning Production",
                    "status": "pending",
                    "estimatedMinutes": 240,
                    "deadline": deadline,
                },
                {
                    "id": "3",
                    "title": "Research Reading",
                    "courseName": "AI",
                    "status": "pending",
                    "estimatedMinutes": 180,
                    "deadline": deadline,
                },
            ],
        },
    )

    assert response.status_code == 200
    data = response.json()
    by_title = {item["taskTitle"]: item for item in data["items"]}
    assert by_title["Final Submissions"]["hoursNeeded"] == 2
    assert by_title["Docker Workflow"]["hoursNeeded"] == 4
    assert by_title["Research Reading"]["hoursNeeded"] == 3

    today_items = [
        item for item in data["items"] if item["suggestedDate"] == today
    ]
    assert {item["taskTitle"] for item in today_items} == {
        "Final Submissions",
        "Docker Workflow",
    }
    assert sum(item["hoursNeeded"] for item in today_items) == 6

    totals_by_day = {}
    for item in data["items"]:
        totals_by_day[item["suggestedDate"]] = (
            totals_by_day.get(item["suggestedDate"], 0) + item["hoursNeeded"]
        )
    assert all(total <= 7 for total in totals_by_day.values())


def test_generate_plan_prioritizes_imminent_pending_before_missed_backlog(monkeypatch):
    now = datetime.now()
    today = now.strftime("%Y-%m-%d")
    final_deadline = (now + timedelta(days=1, hours=6)).isoformat()
    old_deadline = (now - timedelta(days=30)).isoformat()

    # The model puts missed work first. The backend must correct the schedule.
    items = [
        {
            "taskTitle": "Old Missed Task A",
            "courseName": "ML Production",
            "suggestedDate": today,
            "suggestedTime": "09:00-12:00",
            "hoursNeeded": 3,
            "priority": "urgent",
            "tip": "Review the old assignment requirements and complete the missing deliverable.",
        },
        {
            "taskTitle": "Old Missed Task B",
            "courseName": "ML Production",
            "suggestedDate": today,
            "suggestedTime": "12:00-15:00",
            "hoursNeeded": 3,
            "priority": "urgent",
            "tip": "Finish the overdue deployment notes and prepare the submission files.",
        },
        {
            "taskTitle": "Final Submissions",
            "courseName": "Senior Project",
            "suggestedDate": (now + timedelta(days=2)).strftime("%Y-%m-%d"),
            "suggestedTime": "09:00-13:00",
            "hoursNeeded": 4,
            "priority": "high",
            "tip": "Finalize the report, presentation, and submission package.",
        },
    ]
    monkeypatch.setattr(planner, "_llm_provider", _mock_provider_with_items(items))

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "defaultDailyHours": 6,
            "dailyHours": [{"date": today, "hours": 6}],
            "tasks": [
                {
                    "id": "missed-a",
                    "title": "Old Missed Task A",
                    "status": "missed",
                    "estimatedMinutes": 180,
                    "deadline": old_deadline,
                },
                {
                    "id": "missed-b",
                    "title": "Old Missed Task B",
                    "status": "missed",
                    "estimatedMinutes": 180,
                    "deadline": old_deadline,
                },
                {
                    "id": "final",
                    "title": "Final Submissions",
                    "courseName": "Senior Project",
                    "status": "pending",
                    "estimatedMinutes": 240,
                    "deadline": final_deadline,
                },
            ],
        },
    )

    assert response.status_code == 200
    data = response.json()
    by_title = {item["taskTitle"]: item for item in data["items"]}
    final_item = by_title["Final Submissions"]
    assert final_item["priority"] == "urgent"
    assert final_item["suggestedDate"] <= final_deadline[:10]

    final_key = (final_item["suggestedDate"], final_item["suggestedTime"])
    missed_keys = [
        (item["suggestedDate"], item["suggestedTime"])
        for title, item in by_title.items()
        if title.startswith("Old Missed")
    ]
    assert all(final_key <= key for key in missed_keys)


def test_generate_plan_keeps_same_day_window_before_exact_deadline(monkeypatch):
    now = datetime.now()
    deadline = now.replace(hour=11, minute=0, second=0, microsecond=0)
    if deadline <= now:
        deadline = (now + timedelta(days=1)).replace(
            hour=11, minute=0, second=0, microsecond=0
        )
    date_key = deadline.strftime("%Y-%m-%d")

    items = [
        {
            "taskTitle": "Morning Deadline Task",
            "courseName": "AI",
            "suggestedDate": date_key,
            "suggestedTime": "12:00-14:00",
            "hoursNeeded": 2,
            "priority": "high",
            "tip": "Prepare and submit the morning deadline deliverable.",
        }
    ]
    monkeypatch.setattr(planner, "_llm_provider", _mock_provider_with_items(items))

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "defaultDailyHours": 6,
            "dailyHours": [{"date": date_key, "hours": 6}],
            "tasks": [
                {
                    "id": "morning",
                    "title": "Morning Deadline Task",
                    "courseName": "AI",
                    "status": "pending",
                    "estimatedMinutes": 120,
                    "deadline": deadline.isoformat(),
                }
            ],
        },
    )

    assert response.status_code == 200
    item = response.json()["items"][0]
    assert item["suggestedDate"] <= date_key
    assert item["suggestedTime"].endswith("11:00")


def test_generate_plan_uses_llm_tip_completion_for_omitted_tasks(monkeypatch):
    deadline = (datetime.now() + timedelta(days=3)).isoformat()
    provider = _mock_provider_with_tip_completion(
        initial_items=[
            {
                "taskTitle": "Final Submissions",
                "courseName": "Senior Project",
                "suggestedDate": datetime.now().strftime("%Y-%m-%d"),
                "suggestedTime": "09:00-11:00",
                "hoursNeeded": 2,
                "priority": "urgent",
                "tip": "Review the final report, presentation, and upload checklist before submitting.",
            }
        ],
        tip_items=[
            {
                "taskTitle": "Docker Workflow",
                "tip": "Trace the CI/CD pipeline from Dockerfile to deployment and verify each command against the assignment rubric.",
            }
        ],
    )
    monkeypatch.setattr(planner, "_llm_provider", provider)

    response = client.post(
        "/api/plan/generate",
        json={
            "studentName": "Pakinam",
            "tasks": [
                {
                    "id": "final",
                    "title": "Final Submissions",
                    "courseName": "Senior Project",
                    "status": "pending",
                    "estimatedMinutes": 120,
                    "deadline": deadline,
                },
                {
                    "id": "docker",
                    "title": "Docker Workflow",
                    "courseName": "ML Production",
                    "status": "pending",
                    "estimatedMinutes": 120,
                    "deadline": deadline,
                },
            ],
        },
    )

    assert response.status_code == 200
    by_title = {item["taskTitle"]: item for item in response.json()["items"]}
    assert provider.calls == 2
    assert by_title["Docker Workflow"]["tip"].startswith("Trace the CI/CD pipeline")
