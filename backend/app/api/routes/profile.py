from datetime import datetime
import json
import os
from typing import Dict, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.core.security_utils import (
    is_safe_path_segment,
    is_valid_email,
    sanitize_display_text,
)

router = APIRouter(prefix="/profile", tags=["profile"])

_DATA_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
    "data",
)
_DATA_FILE = os.path.join(_DATA_DIR, "profiles.json")


class ProfileRecord(BaseModel):
    userId: str
    fullName: str
    email: str
    studentId: Optional[str] = ""
    major: Optional[str] = ""
    academicYear: Optional[str] = ""
    gpa: Optional[str] = ""
    updatedAt: str


class UpdateProfileRequest(BaseModel):
    fullName: str
    email: str
    studentId: Optional[str] = None
    major: Optional[str] = None
    academicYear: Optional[str] = None
    gpa: Optional[str] = None


def _ensure_store() -> None:
    os.makedirs(_DATA_DIR, exist_ok=True)
    if not os.path.exists(_DATA_FILE):
        with open(_DATA_FILE, "w", encoding="utf-8") as f:
            json.dump({"profiles": {}}, f, ensure_ascii=True, indent=2)


def _load_store() -> Dict:
    _ensure_store()
    try:
        with open(_DATA_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            if not isinstance(data, dict):
                return {"profiles": {}}
            data.setdefault("profiles", {})
            return data
    except Exception:
        return {"profiles": {}}


def _save_store(data: Dict) -> None:
    _ensure_store()
    with open(_DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=True, indent=2)


def _default_profile(user_id: str) -> Dict:
    return ProfileRecord(
        userId=user_id,
        fullName="",
        email="",
        studentId="",
        major="",
        academicYear="",
        gpa="",
        updatedAt=datetime.utcnow().isoformat(),
    ).model_dump(mode="json")


@router.get("/{user_id}")
async def get_profile(user_id: str):
    if not is_safe_path_segment(user_id):
        raise HTTPException(status_code=400, detail="Invalid user id")

    data = _load_store()
    profile = data["profiles"].get(user_id)

    if profile is None:
        profile = _default_profile(user_id)
        data["profiles"][user_id] = profile
        _save_store(data)

    return {"success": True, "profile": profile}


@router.patch("/{user_id}")
async def update_profile(user_id: str, body: UpdateProfileRequest):
    if not is_safe_path_segment(user_id):
        raise HTTPException(status_code=400, detail="Invalid user id")

    if not is_valid_email(body.email):
        raise HTTPException(status_code=400, detail="Invalid email address")

    data = _load_store()
    current = data["profiles"].get(user_id) or _default_profile(user_id)

    current["fullName"] = sanitize_display_text(body.fullName)
    current["email"] = body.email.strip()
    current["studentId"] = body.studentId or current.get("studentId") or ""

    current["major"] = sanitize_display_text(
        body.major or current.get("major") or ""
    )

    current["academicYear"] = sanitize_display_text(
        body.academicYear or current.get("academicYear") or ""
    )

    current["gpa"] = body.gpa or current.get("gpa") or ""
    current["updatedAt"] = datetime.utcnow().isoformat()

    data["profiles"][user_id] = current
    _save_store(data)

    return {"success": True, "profile": current}