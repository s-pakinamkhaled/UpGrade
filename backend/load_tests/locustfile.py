"""
UpGrade backend — Locust performance tests.

Prerequisites:
  pip install -r requirements-load.txt
  uvicorn app.main:app --host 127.0.0.1 --port 8001   (from backend/)

Quick start (web UI):
  cd backend
  locust -f load_tests/locustfile.py --host http://127.0.0.1:8001

Headless load test:
  $env:LOCUST_TEST_TYPE="load"
  locust -f load_tests/locustfile.py --host http://127.0.0.1:8001 `
    --headless --html load_tests/reports/load_report.html

Stress / soak:
  $env:LOCUST_TEST_TYPE="stress"   # or "soak"
  locust -f load_tests/locustfile.py --host http://127.0.0.1:8001 --headless

AI endpoints (Groq) are OFF by default — set ENABLE_AI_TASKS=true to include them.
Use a separate run for AI capacity; core API capacity is measured without Groq limits.
"""
from __future__ import annotations

import os
import random
import sys

# Allow imports from load_tests/ when Locust loads this file.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from locust import HttpUser, between, events, tag, task

from fixtures import (
    new_task_id,
    new_user_id,
    sample_chat_payload,
    sample_profile_update,
    sample_study_group_suggestion,
    sample_task_payload,
    sample_tasks_for_planner,
)
from shapes import active_shape

ENABLE_AI = os.getenv("ENABLE_AI_TASKS", "false").lower() in ("1", "true", "yes")


class CoreApiUser(HttpUser):
    """
    Typical student session — health, tasks, profile, study groups.
    Use this class for load / stress / soak capacity numbers.
    """

    weight = 10 if ENABLE_AI else 1
    wait_time = between(0.5, 2.5)

    def on_start(self):
        self.user_id = new_user_id("student")
        self.task_ids: list[str] = []

    @tag("health")
    @task(5)
    def health_checks(self):
        with self.client.get("/health", name="/health", catch_response=True) as resp:
            if resp.status_code != 200:
                resp.failure(f"health failed: {resp.status_code}")
        with self.client.get("/api/health", name="/api/health", catch_response=True) as resp:
            if resp.status_code != 200:
                resp.failure(f"api health failed: {resp.status_code}")

    @tag("tasks")
    @task(4)
    def task_lifecycle(self):
        task_id = new_task_id()
        payload = sample_task_payload(self.user_id, task_id)

        with self.client.post(
            "/api/tasks",
            json=payload,
            name="POST /api/tasks",
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(resp.text)
                return
        self.task_ids.append(task_id)

        with self.client.get(
            f"/api/tasks/{task_id}",
            name="GET /api/tasks/{id}",
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(resp.text)

        with self.client.patch(
            f"/api/tasks/{task_id}/status",
            json={"status": "inProgress", "userId": self.user_id},
            name="PATCH /api/tasks/{id}/status",
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(resp.text)

        with self.client.get(
            "/api/tasks/activity/logs",
            name="GET /api/tasks/activity/logs",
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(resp.text)

    @tag("profile")
    @task(2)
    def profile_flow(self):
        with self.client.get(
            f"/api/profile/{self.user_id}",
            name="GET /api/profile/{userId}",
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(resp.text)

        with self.client.patch(
            f"/api/profile/{self.user_id}",
            json=sample_profile_update(),
            name="PATCH /api/profile/{userId}",
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(resp.text)

    @tag("study_groups")
    @task(2)
    def study_group_suggestions(self):
        suggestion = sample_study_group_suggestion(self.user_id)
        with self.client.post(
            "/api/study-groups/suggestions",
            json=suggestion,
            name="POST /api/study-groups/suggestions",
            catch_response=True,
        ) as resp:
            if resp.status_code not in (200, 422):
                resp.failure(resp.text)

        with self.client.get(
            "/api/study-groups/suggestions",
            params={
                "creator_id": self.user_id,
                "creator_name": "Locust User",
                "course_id": "cs101",
                "course_name": "Database Systems",
                "goal": "Exam prep",
                "preferred_meeting_time": "18:00",
                "available_start": suggestion["availableStart"],
                "available_end": suggestion["availableEnd"],
                "topic": "Normalization",
            },
            name="GET /api/study-groups/suggestions",
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(resp.text)

        with self.client.get(
            "/api/study-groups/my-groups",
            params={"userId": self.user_id},
            name="GET /api/study-groups/my-groups",
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(resp.text)


class AiChatUser(HttpUser):
    """AI chat endpoints — enable with ENABLE_AI_TASKS=true (hits Groq)."""

    weight = 2 if ENABLE_AI else 0
    wait_time = between(2, 6)

    def on_start(self):
        self.user_id = new_user_id("ai_chat")

    @tag("ai", "chat")
    @task(3)
    def chat_suggestions(self):
        urgent = random.choice([True, False])
        with self.client.get(
            "/api/chat/suggestions",
            params={
                "has_urgent_tasks": urgent,
                "has_upcoming_deadline": not urgent,
            },
            name="GET /api/chat/suggestions",
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(resp.text)

    @tag("ai", "chat")
    @task(1)
    def chat_message(self):
        with self.client.post(
            "/api/chat/message",
            json=sample_chat_payload(f"Student_{self.user_id[-6:]}"),
            name="POST /api/chat/message",
            catch_response=True,
        ) as resp:
            if resp.status_code == 503:
                resp.failure("chat service unavailable")
            elif resp.status_code != 200:
                resp.failure(resp.text)
            elif resp.json().get("success") is not True:
                resp.failure("chat success=false")


class AiPlannerUser(HttpUser):
    """AI study plan generation — heavy; enable with ENABLE_AI_TASKS=true."""

    weight = 1 if ENABLE_AI else 0
    wait_time = between(5, 15)

    @tag("ai", "planner")
    @task(2)
    def planner_health(self):
        with self.client.get(
            "/api/plan/health",
            name="GET /api/plan/health",
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(resp.text)

    @tag("ai", "planner")
    @task(1)
    def generate_plan(self):
        with self.client.post(
            "/api/plan/generate",
            json={
                "studentName": "Locust Student",
                "tasks": sample_tasks_for_planner(),
            },
            name="POST /api/plan/generate",
            catch_response=True,
        ) as resp:
            if resp.status_code == 503:
                resp.failure("planner unavailable")
            elif resp.status_code != 200:
                resp.failure(resp.text)
            elif resp.json().get("success") is not True:
                resp.failure("plan success=false")


# Active load shape (load / stress / soak) — see shapes.py
Shape = active_shape()


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    kind = os.getenv("LOCUST_TEST_TYPE", "load")
    ai = "enabled" if ENABLE_AI else "disabled"
    print(f"[UpGrade Locust] test_type={kind} ai_tasks={ai} host={environment.host}")


@events.quitting.add_listener
def on_quitting(environment, **kwargs):
    stats = environment.runner.stats
    total = stats.total
    if total.num_requests == 0:
        return
    fail_pct = total.num_failures / total.num_requests * 100
    print(
        f"[UpGrade Locust] summary: requests={total.num_requests} "
        f"failures={total.num_failures} ({fail_pct:.2f}%) "
        f"avg_ms={total.avg_response_time:.0f} p95_ms={total.get_response_time_percentile(0.95):.0f}"
    )
