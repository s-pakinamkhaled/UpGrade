from __future__ import annotations

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Literal, Optional
from uuid import uuid4

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field, model_validator

from app.core.security_utils import is_safe_path_segment
from app.services.study_group_matching_service import score_candidates

router = APIRouter(prefix="/study-groups", tags=["study-groups"])

_STATUS_VALUES = ("pending", "active", "completed")
_DATA_FILE = Path(__file__).resolve().parents[3] / "data" / "study_groups.json"


class GroupMemberSchema(BaseModel):
    userId: str
    name: str
    matchScore: Optional[int] = None


class StudyGroupCreateRequest(BaseModel):
    creatorId: str
    creatorName: str
    courseId: str
    courseName: str
    assignmentId: Optional[str] = None
    assignmentTitle: Optional[str] = None
    assignmentDeadline: Optional[str] = None
    topic: Optional[str] = None
    goal: str
    preferredMeetingTime: str
    availableStart: str
    availableEnd: str
    maxGroupSize: int = Field(default=4, ge=2, le=12)
    riskLevel: Optional[str] = None
    workloadScore: Optional[int] = Field(default=None, ge=0, le=100)
    candidateStudents: Optional[List[Dict[str, Any]]] = None
    selectedMemberIds: Optional[List[str]] = None

    @model_validator(mode="after")
    def validate_assignment_or_topic(self):
        if not self.assignmentId and not self.topic:
            raise ValueError("Either assignmentId or topic is required.")
        return self


class StudyGroupSuggestionResponse(BaseModel):
    groupName: str
    courseName: str
    goal: str
    relatedAssignmentOrTopic: str
    suggestedMeetingTime: str
    status: Literal["pending", "active", "completed"]
    suggestedMembers: List[Dict[str, Any]]


class StudyGroupCreateResponse(BaseModel):
    success: bool
    group: Dict[str, Any]
    message: Optional[str] = None


class StudyGroupStatusUpdateRequest(BaseModel):
    status: Literal["pending", "active", "completed"]


def _ensure_data_file() -> None:
    if not _DATA_FILE.parent.exists():
        _DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    if not _DATA_FILE.exists():
        payload = {"groups": []}
        _DATA_FILE.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _load_data() -> Dict[str, Any]:
    _ensure_data_file()
    try:
        return json.loads(_DATA_FILE.read_text(encoding="utf-8"))
    except Exception:
        return {"groups": []}


def _save_data(data: Dict[str, Any]) -> None:
    _ensure_data_file()
    _DATA_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")


def _seed_candidates(request: StudyGroupCreateRequest) -> List[Dict[str, Any]]:
    now = datetime.now()
    start = now.replace(hour=18, minute=0, second=0, microsecond=0).isoformat()
    end = now.replace(hour=21, minute=0, second=0, microsecond=0).isoformat()
    return [
        {
            "id": "peer_1",
            "name": "Alex Rivera",
            "courseIds": [request.courseId],
            "assignments": [
                {
                    "assignmentId": request.assignmentId,
                    "deadline": request.assignmentDeadline,
                },
            ],
            "studyGoals": [request.goal, "quiz revision"],
            "availableStart": start,
            "availableEnd": end,
            "riskLevel": "medium",
            "workloadScore": 60,
        },
        {
            "id": "peer_2",
            "name": "Sam Chen",
            "courseIds": [request.courseId],
            "assignments": [
                {
                    "assignmentId": "other_assignment",
                    "deadline": request.assignmentDeadline,
                },
            ],
            "studyGoals": [request.goal],
            "availableStart": start,
            "availableEnd": end,
            "riskLevel": "high",
            "workloadScore": 70,
        },
        {
            "id": "peer_3",
            "name": "Jordan Lee",
            "courseIds": ["other_course"],
            "assignments": [],
            "studyGoals": ["general study session"],
            "availableStart": start,
            "availableEnd": end,
            "riskLevel": "low",
            "workloadScore": 35,
        },
    ]


def _build_group_name(req: StudyGroupCreateRequest) -> str:
    target = req.assignmentTitle or req.topic or "Study Session"
    return f"{req.courseName} {target} Group"


def _build_related_topic(req: StudyGroupCreateRequest) -> str:
    return req.assignmentTitle or req.topic or "General Study Session"


@router.get("/suggestions", response_model=StudyGroupSuggestionResponse)
def get_suggestions(
    creator_id: str = Query(...),
    creator_name: str = Query(...),
    course_id: str = Query(...),
    course_name: str = Query(...),
    goal: str = Query(...),
    preferred_meeting_time: str = Query(...),
    available_start: str = Query(...),
    available_end: str = Query(...),
    max_group_size: int = Query(4, ge=2, le=12),
    assignment_id: Optional[str] = Query(None),
    assignment_title: Optional[str] = Query(None),
    assignment_deadline: Optional[str] = Query(None),
    topic: Optional[str] = Query(None),
    risk_level: Optional[str] = Query(None),
    workload_score: Optional[int] = Query(None, ge=0, le=100),
):
    req = StudyGroupCreateRequest(
        creatorId=creator_id,
        creatorName=creator_name,
        courseId=course_id,
        courseName=course_name,
        assignmentId=assignment_id,
        assignmentTitle=assignment_title,
        assignmentDeadline=assignment_deadline,
        topic=topic,
        goal=goal,
        preferredMeetingTime=preferred_meeting_time,
        availableStart=available_start,
        availableEnd=available_end,
        maxGroupSize=max_group_size,
        riskLevel=risk_level,
        workloadScore=workload_score,
    )
    data = _load_data()
    candidates = _seed_candidates(req)
    ranked = score_candidates(req.model_dump(), candidates, data.get("groups", []))
    return StudyGroupSuggestionResponse(
        groupName=_build_group_name(req),
        courseName=req.courseName,
        goal=req.goal,
        relatedAssignmentOrTopic=_build_related_topic(req),
        suggestedMeetingTime=req.preferredMeetingTime,
        status="pending",
        suggestedMembers=ranked[: max(0, req.maxGroupSize - 1)],
    )


@router.post("/suggestions", response_model=StudyGroupSuggestionResponse)
def post_suggestions(request: StudyGroupCreateRequest):
    data = _load_data()
    candidates = request.candidateStudents or _seed_candidates(request)
    ranked = score_candidates(request.model_dump(), candidates, data.get("groups", []))
    return StudyGroupSuggestionResponse(
        groupName=_build_group_name(request),
        courseName=request.courseName,
        goal=request.goal,
        relatedAssignmentOrTopic=_build_related_topic(request),
        suggestedMeetingTime=request.preferredMeetingTime,
        status="pending",
        suggestedMembers=ranked[: max(0, request.maxGroupSize - 1)],
    )


@router.post("/create", response_model=StudyGroupCreateResponse)
def create_study_group(request: StudyGroupCreateRequest):
    data = _load_data()
    groups = data.get("groups", [])
    if not isinstance(groups, list):
        groups = []

    candidates = request.candidateStudents or _seed_candidates(request)
    ranked = score_candidates(request.model_dump(), candidates, groups)
    selected_ids = set(request.selectedMemberIds or [])
    if selected_ids:
        ranked = [r for r in ranked if r.get("studentId") in selected_ids]

    member_slots = request.maxGroupSize - 1
    selected = ranked[: max(0, member_slots)]

    members = [
        GroupMemberSchema(userId=request.creatorId, name=request.creatorName).model_dump(),
        *[
            GroupMemberSchema(
                userId=item["studentId"],
                name=item["name"],
                matchScore=item.get("score"),
            ).model_dump()
            for item in selected
        ],
    ]

    invited = [item["studentId"] for item in ranked[max(0, member_slots):]]
    now = datetime.utcnow().isoformat()
    group_id = str(uuid4())
    group = {
        "groupId": group_id,
        "creatorId": request.creatorId,
        "courseId": request.courseId,
        "courseName": request.courseName,
        "assignmentId": request.assignmentId,
        "topic": request.topic,
        "goal": request.goal,
        "members": members,
        "invitedUsers": invited,
        "maxGroupSize": request.maxGroupSize,
        "meetingTime": request.preferredMeetingTime,
        "availableStart": request.availableStart,
        "availableEnd": request.availableEnd,
        "status": "pending",
        "createdAt": now,
        "updatedAt": now,
        "relatedAssignmentOrTopic": _build_related_topic(request),
        "groupName": _build_group_name(request),
    }

    if len(members) <= 1:
        raise HTTPException(
            status_code=404,
            detail="No matching students found for this request.",
        )

    if len(members) > request.maxGroupSize:
        raise HTTPException(status_code=409, detail="Group already full.")

    groups.append(group)
    data["groups"] = groups
    _save_data(data)
    return StudyGroupCreateResponse(
        success=True,
        group=group,
        message="Study group created successfully.",
    )


@router.get("/my-groups")
def get_my_groups(
    user_id: str = Query(..., alias="userId"),
):
    if not is_safe_path_segment(user_id):
        raise HTTPException(status_code=400, detail="Invalid user id")
    data = _load_data()
    groups = data.get("groups", [])
    if not isinstance(groups, list):
        groups = []

    mine = []
    for group in groups:
        if group.get("creatorId") == user_id:
            mine.append(group)
            continue
        member_ids = [m.get("userId") for m in group.get("members", []) if isinstance(m, dict)]
        if user_id in member_ids:
            mine.append(group)

    return {"groups": mine}


@router.patch("/{group_id}/status")
def update_status(group_id: str, request: StudyGroupStatusUpdateRequest):
    if not is_safe_path_segment(group_id):
        raise HTTPException(status_code=400, detail="Invalid group id")
    data = _load_data()
    groups = data.get("groups", [])
    if not isinstance(groups, list):
        groups = []

    for group in groups:
        if group.get("groupId") == group_id:
            group["status"] = request.status
            group["updatedAt"] = datetime.utcnow().isoformat()
            _save_data(data)
            return {"success": True, "group": group}

    raise HTTPException(status_code=404, detail="Group not found.")
