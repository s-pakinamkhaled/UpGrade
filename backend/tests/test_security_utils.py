import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.security_utils import (
    MAX_CHAT_MESSAGE_LEN,
    filter_invite_emails,
    is_safe_path_segment,
    is_valid_email,
    sanitize_display_text,
    validate_chat_message,
)


def test_is_safe_path_segment_rejects_traversal():
    assert is_safe_path_segment("../admin") is False
    assert is_safe_path_segment("user/1") is False
    assert is_safe_path_segment("id?x=1") is False
    assert is_safe_path_segment("student_001") is True


def test_is_valid_email_rejects_malformed():
    assert is_valid_email("not-an-email") is False
    assert is_valid_email("spaces @test.com") is False
    assert is_valid_email("pakinam@test.com") is True


def test_filter_invite_emails_dedupes_and_validates():
    result = filter_invite_emails(
        ["a@test.com", "a@test.com", "bad", "", "b@test.com"]
    )
    assert result == ["a@test.com", "b@test.com"]


def test_sanitize_display_text_collapses_and_caps():
    assert sanitize_display_text("  Hello   world  ") == "Hello world"
    assert len(sanitize_display_text("A" * 300)) == 200


def test_validate_chat_message_rules():
    assert validate_chat_message("") == "Message is required"
    assert validate_chat_message("   ") == "Message is required"
    assert validate_chat_message("A" * (MAX_CHAT_MESSAGE_LEN + 1)) is not None
    assert validate_chat_message("What should I study?") is None
