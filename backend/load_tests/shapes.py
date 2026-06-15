"""
Locust load shapes for load / stress / soak testing.

Set LOCUST_TEST_TYPE=load|stress|soak before starting Locust.
Override stages with env vars documented in each class.
"""
from __future__ import annotations

import os

from locust import LoadTestShape


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, str(default)))
    except ValueError:
        return default


class LoadTestShapeConfig(LoadTestShape):
    """
    Normal load test - find sustainable throughput under expected traffic.

    Default stages:
      {"duration": 120, "users": 2000, "spawn_rate": 20}  ramp up
      {"duration": 420, "users": 2000, "spawn_rate": 20}  hold 5 min
      {"duration": 480, "users": 0,    "spawn_rate": 20}  ramp down

    Env: LOAD_PEAK_USERS, LOAD_RAMP_SECONDS, LOAD_HOLD_SECONDS, LOAD_SPAWN_RATE
    """

    peak = _env_int("LOAD_PEAK_USERS", 2000)
    ramp = _env_int("LOAD_RAMP_SECONDS", 120)
    hold = _env_int("LOAD_HOLD_SECONDS", 300)
    spawn_rate = _env_int("LOAD_SPAWN_RATE", 20)

    stages = [
        {"duration": ramp, "users": peak, "spawn_rate": spawn_rate},
        {"duration": ramp + hold, "users": peak, "spawn_rate": spawn_rate},
        {"duration": ramp + hold + 60, "users": 0, "spawn_rate": spawn_rate},
    ]

    def tick(self):
        run_time = self.get_run_time()
        for stage in self.stages:
            if run_time < stage["duration"]:
                return stage["users"], stage["spawn_rate"]
        return None


class StressTestShapeConfig(LoadTestShape):
    """
    Stress test - increase load until errors or latency spike.

    Default: 100 -> 200 -> 300 -> ... up to 3000 users (step 100 every 60s).
    Env: STRESS_MAX_USERS, STRESS_STEP_USERS, STRESS_STEP_SECONDS, STRESS_SPAWN_RATE
    """

    step_seconds = _env_int("STRESS_STEP_SECONDS", 60)
    step_users = _env_int("STRESS_STEP_USERS", 100)
    max_users = _env_int("STRESS_MAX_USERS", 3000)
    spawn_rate = _env_int("STRESS_SPAWN_RATE", 20)

    def tick(self):
        run_time = self.get_run_time()
        if run_time >= self.step_seconds * (self.max_users // self.step_users + 2):
            return None

        step_index = int(run_time // self.step_seconds) + 1
        users = min(step_index * self.step_users, self.max_users)
        return users, self.spawn_rate


class SoakTestShapeConfig(LoadTestShape):
    """
    Soak test - moderate steady load for a long period (memory leaks, DB growth).

    Default: {"duration": soak_min*60, "users": 2000, "spawn_rate": 20}
    Env: SOAK_USERS, SOAK_DURATION_MINUTES, SOAK_SPAWN_RATE
    """

    users = _env_int("SOAK_USERS", 2000)
    duration_min = _env_int("SOAK_DURATION_MINUTES", 30)
    spawn_rate = _env_int("SOAK_SPAWN_RATE", 20)

    def tick(self):
        run_time = self.get_run_time()
        if run_time > self.duration_min * 60:
            return None
        return self.users, self.spawn_rate


def active_shape():
    """Return the shape class selected by LOCUST_TEST_TYPE."""
    kind = os.getenv("LOCUST_TEST_TYPE", "load").lower()
    if kind == "stress":
        return StressTestShapeConfig
    if kind == "soak":
        return SoakTestShapeConfig
    return LoadTestShapeConfig
