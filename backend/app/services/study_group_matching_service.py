from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple


@dataclass
class MatchWeights:
    same_course: int = 40
    same_assignment_or_deadline: int = 25
    overlapping_availability: int = 25
    similar_goal: int = 10
    compatible_risk: int = 10


def _parse_iso(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None


def _time_overlap_minutes(
    a_start: Optional[datetime],
    a_end: Optional[datetime],
    b_start: Optional[datetime],
    b_end: Optional[datetime],
) -> int:
    if not a_start or not a_end or not b_start or not b_end:
        return 0
    latest_start = max(a_start, b_start)
    earliest_end = min(a_end, b_end)
    if earliest_end <= latest_start:
        return 0
    return int((earliest_end - latest_start).total_seconds() // 60)


def _deadline_close(a_deadline: Optional[str], b_deadline: Optional[str]) -> bool:
    a = _parse_iso(a_deadline)
    b = _parse_iso(b_deadline)
    if not a or not b:
        return False
    return abs((a - b).days) <= 3


def _risk_compatible(a_risk: Optional[str], b_risk: Optional[str]) -> bool:
    if not a_risk or not b_risk:
        return False
    order = {"low": 1, "medium": 2, "high": 3}
    av = order.get(a_risk.lower())
    bv = order.get(b_risk.lower())
    if av is None or bv is None:
        return False
    return abs(av - bv) <= 1


def _workload_compatible(a_workload: Optional[int], b_workload: Optional[int]) -> bool:
    if a_workload is None or b_workload is None:
        return False
    return abs(a_workload - b_workload) <= 30


def _has_scheduling_conflict(
    candidate_id: str,
    requested_meeting_time: Optional[str],
    existing_groups: List[Dict[str, Any]],
) -> bool:
    requested = _parse_iso(requested_meeting_time)
    if not requested:
        return False
    for group in existing_groups:
        if group.get("status") not in ("pending", "active"):
            continue
        member_ids = [
            m.get("userId")
            for m in group.get("members", [])
            if isinstance(m, dict)
        ]
        if candidate_id not in member_ids:
            continue
        group_time = _parse_iso(group.get("meetingTime"))
        if not group_time:
            continue
        # Treat 2h around meeting time as busy window.
        if abs((group_time - requested).total_seconds()) <= 2 * 3600:
            return True
    return False


def score_candidates(
    request_payload: Dict[str, Any],
    candidate_students: List[Dict[str, Any]],
    existing_groups: List[Dict[str, Any]],
    weights: MatchWeights = MatchWeights(),
) -> List[Dict[str, Any]]:
    ranked: List[Tuple[int, Dict[str, Any]]] = []

    request_course_id = request_payload.get("courseId")
    request_goal = (request_payload.get("goal") or "").strip().lower()
    request_assignment_id = request_payload.get("assignmentId")
    request_deadline = request_payload.get("assignmentDeadline")
    request_avail_start = _parse_iso(request_payload.get("availableStart"))
    request_avail_end = _parse_iso(request_payload.get("availableEnd"))
    request_risk = request_payload.get("riskLevel")
    request_workload = request_payload.get("workloadScore")
    request_meeting_time = request_payload.get("preferredMeetingTime")

    for candidate in candidate_students:
        candidate_id = candidate.get("id")
        if not candidate_id:
            continue

        if _has_scheduling_conflict(candidate_id, request_meeting_time, existing_groups):
            continue

        score = 0
        reasons: List[str] = []
        courses = candidate.get("courseIds", [])
        if request_course_id and request_course_id in courses:
            score += weights.same_course
            reasons.append("same course")
        else:
            continue

        matched_assignment = False
        for assignment in candidate.get("assignments", []):
            if request_assignment_id and assignment.get("assignmentId") == request_assignment_id:
                matched_assignment = True
                break
            if _deadline_close(request_deadline, assignment.get("deadline")):
                matched_assignment = True
                break
        if matched_assignment:
            score += weights.same_assignment_or_deadline
            reasons.append("same assignment/deadline")

        overlap = _time_overlap_minutes(
            request_avail_start,
            request_avail_end,
            _parse_iso(candidate.get("availableStart")),
            _parse_iso(candidate.get("availableEnd")),
        )
        if overlap >= 30:
            score += weights.overlapping_availability
            reasons.append("overlapping availability")

        goals = [(g or "").strip().lower() for g in candidate.get("studyGoals", [])]
        if request_goal and request_goal in goals:
            score += weights.similar_goal
            reasons.append("similar study goal")

        if _risk_compatible(request_risk, candidate.get("riskLevel")) or _workload_compatible(
            request_workload,
            candidate.get("workloadScore"),
        ):
            score += weights.compatible_risk
            reasons.append("compatible workload/risk")

        ranked.append(
            (
                score,
                {
                    "studentId": candidate_id,
                    "name": candidate.get("name", "Unknown"),
                    "score": score,
                    "reasons": reasons,
                    "riskLevel": candidate.get("riskLevel"),
                    "workloadScore": candidate.get("workloadScore"),
                },
            )
        )

    ranked.sort(key=lambda x: x[0], reverse=True)
    return [item for _, item in ranked]
