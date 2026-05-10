from datetime import datetime
import json
import os
from typing import Dict, Optional

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(prefix="/profile", tags=["profile"])

_DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data")
_DATA_FILE = os.path.join(_DATA_DIR, "profiles.json")


class ProfileRecord(BaseModel):
    userId: str
    fullName: str
    email: str
    major: Optional[str] = "Computer Science"
    academicYear: Optional[str] = "Junior"
    gpa: Optional[str] = "3.85"
    updatedAt: str


class UpdateProfileRequest(BaseModel):
    fullName: str
    email: str
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
    # Empty name/email: the app derives display name from the signed-in user's email
    # and does not show placeholder "John Doe".
    return ProfileRecord(
        userId=user_id,
        fullName="",
        email="",
        major="Computer Science",
        academicYear="Junior",
        gpa="3.85",
        updatedAt=datetime.utcnow().isoformat(),
    ).model_dump(mode="json")


@router.get("/{user_id}")
async def get_profile(user_id: str):
    data = _load_store()
    profile = data["profiles"].get(user_id)
    if profile is None:
        profile = _default_profile(user_id)
        data["profiles"][user_id] = profile
        _save_store(data)
    return {"success": True, "profile": profile}


@router.patch("/{user_id}")
async def update_profile(user_id: str, body: UpdateProfileRequest):
    data = _load_store()
    current = data["profiles"].get(user_id) or _default_profile(user_id)

    current["fullName"] = body.fullName
    current["email"] = body.email
    current["major"] = body.major or current.get("major") or "Computer Science"
    current["academicYear"] = body.academicYear or current.get("academicYear") or "Junior"
    current["gpa"] = body.gpa or current.get("gpa") or "3.85"
    current["updatedAt"] = datetime.utcnow().isoformat()

    data["profiles"][user_id] = current
    _save_store(data)
    return {"success": True, "profile": current}
