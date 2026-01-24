"""
Load testing with Locust.
"""
from locust import HttpUser, task, between

class UpgradeUser(HttpUser):
    wait_time = between(1, 3)
    token = None

    def on_start(self):
        """Login and get token."""
        response = self.client.post("/auth/login", json={
            "email": "test@example.com",
            "password": "testpassword"
        })
        if response.status_code == 200:
            self.token = response.json().get("access_token")
            self.client.headers = {"Authorization": f"Bearer {self.token}"}

    @task(3)
    def get_tasks(self):
        """Get user tasks."""
        self.client.get("/tasks/")

    @task(2)
    def get_study_plans(self):
        """Get study plans."""
        self.client.get("/planner/")

    @task(1)
    def create_task(self):
        """Create a new task."""
        self.client.post("/tasks/", json={
            "title": "Load Test Task",
            "description": "Generated during load test",
            "priority": 5
        })

