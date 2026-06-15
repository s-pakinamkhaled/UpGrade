import sys
import os

sys.path.append(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

from datetime import datetime

from app.services.study_group_matching_service import (
    _deadline_close,
    _risk_compatible,
    _workload_compatible,
    _time_overlap_minutes,
)


def test_deadline_close_true():
    assert _deadline_close(
        "2026-06-10T10:00:00",
        "2026-06-12T10:00:00",
    ) is True


def test_deadline_close_false():
    assert _deadline_close(
        "2026-06-10T10:00:00",
        "2026-06-25T10:00:00",
    ) is False


def test_risk_compatible_true():
    assert _risk_compatible("high", "medium") is True


def test_risk_compatible_false():
    assert _risk_compatible("high", "low") is False


def test_workload_compatible_true():
    assert _workload_compatible(80, 60) is True


def test_workload_compatible_false():
    assert _workload_compatible(100, 20) is False


def test_time_overlap_exists():
    a_start = datetime.fromisoformat("2026-06-01T10:00:00")
    a_end = datetime.fromisoformat("2026-06-01T12:00:00")

    b_start = datetime.fromisoformat("2026-06-01T11:00:00")
    b_end = datetime.fromisoformat("2026-06-01T13:00:00")

    assert _time_overlap_minutes(
        a_start,
        a_end,
        b_start,
        b_end,
    ) == 60


def test_time_overlap_none():
    a_start = datetime.fromisoformat("2026-06-01T10:00:00")
    a_end = datetime.fromisoformat("2026-06-01T11:00:00")

    b_start = datetime.fromisoformat("2026-06-01T12:00:00")
    b_end = datetime.fromisoformat("2026-06-01T13:00:00")

    assert _time_overlap_minutes(
        a_start,
        a_end,
        b_start,
        b_end,
    ) == 0
