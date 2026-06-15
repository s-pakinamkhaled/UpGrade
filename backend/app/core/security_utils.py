"""Shared input validation and security helpers for API routes."""
from __future__ import annotations

import re
from typing import List, Optional

MAX_PATH_SEGMENT_LEN = 128
MAX_DISPLAY_FIELD_LEN = 200
MAX_CHAT_MESSAGE_LEN = 4000
EMAIL_MAX_LEN = 254

_UNSAFE_PATH_CHARS = ("/", "\\", "..", "?", "#")


def is_safe_path_segment(value: Optional[str]) -> bool:
    """Reject path traversal and query fragments in REST path segments."""
    if value is None:
        return False
    trimmed = value.strip()
    if not trimmed or len(trimmed) > MAX_PATH_SEGMENT_LEN:
        return False
    return not any(marker in trimmed for marker in _UNSAFE_PATH_CHARS)


def sanitize_display_text(
    value: str,
    max_length: int = MAX_DISPLAY_FIELD_LEN,
) -> str:
    """Trim, collapse whitespace, and cap free-text fields."""
    collapsed = re.sub(r"\s+", " ", value.strip())
    if len(collapsed) <= max_length:
        return collapsed
    return collapsed[:max_length]


def is_valid_email(value: Optional[str]) -> bool:
    if value is None:
        return False
    trimmed = value.strip()
    if not trimmed or len(trimmed) > EMAIL_MAX_LEN or " " in trimmed:
        return False
    if trimmed.count("@") != 1:
        return False
    local, domain = trimmed.split("@", 1)
    if not local or not domain or "." not in domain:
        return False
    if domain.startswith(".") or domain.endswith("."):
        return False
    if len(domain.split(".")[-1]) < 2:
        return False
    return True


def filter_invite_emails(emails: List[str]) -> List[str]:
    """Trim, dedupe, and keep only valid recipient addresses."""
    seen = set()
    result: List[str] = []
    for raw in emails:
        email = raw.strip()
        if not email or email in seen:
            continue
        if is_valid_email(email):
            seen.add(email)
            result.append(email)
    return result


def validate_chat_message(message: Optional[str]) -> Optional[str]:
    """Return an error string when the chat message is unsafe to process."""
    if message is None or not message.strip():
        return "Message is required"
    if len(message) > MAX_CHAT_MESSAGE_LEN:
        return "Message exceeds maximum length"
    return None
