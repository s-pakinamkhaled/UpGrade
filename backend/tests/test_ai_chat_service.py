"""
Unit tests for AIChatService (ai/chat_service.py).

Uses a mock LLMProvider so no real API calls are made.

Updated to reflect the refactored AIChatService which now uses LLMProvider
instead of directly calling GroqClient.  The public chat() contract and
get_quick_suggestions() behaviour are unchanged.
"""

import os
import sys

_AI_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "ai"
)
if _AI_PATH not in sys.path:
    sys.path.insert(0, _AI_PATH)

from chat_service import AIChatService
from llm.config import LLMConfig
from llm.provider import GenerationResult


class MockLLMProvider:
    """Minimal LLMProvider mock for unit tests."""

    def __init__(self, response_content: str = "Focus on your urgent tasks first.",
                 raise_error: bool = False):
        self.response_content = response_content
        self.raise_error = raise_error
        self.last_messages = None
        self.last_model = None
        self.last_kwargs = {}

    def generate_text(self, messages, model, fallback_model, **kwargs):
        if self.raise_error:
            raise RuntimeError("Provider unavailable")
        self.last_messages = messages
        self.last_model = model
        self.last_kwargs = kwargs
        return GenerationResult(
            content=self.response_content,
            model=model,
            provider="groq",
            used_fallback=False,
            latency_ms=50.0,
        )


class MockJudge:
    def evaluate_chat_response(self, **kwargs):
        pass


def _service_with_mock(provider=None, judge=None, enable_judge=False):
    """Create an AIChatService with injected mocks (bypasses __init__)."""
    service = AIChatService.__new__(AIChatService)
    service.provider = provider or MockLLMProvider()
    service.judge = judge or MockJudge()
    service.config = LLMConfig(
        chat_model="llama-3.3-70b-versatile",
        chat_fallback_model="llama-3.1-8b-instant",
        llm_provider="groq",
        enable_chatbot_judge=enable_judge,
    )
    service.system_prompt = AIChatService._get_system_prompt()
    return service


# ── Basic chat response ────────────────────────────────────────────────────────


def test_chat_returns_success_message():
    service = _service_with_mock()

    result = service.chat("What should I study now?")

    assert result["success"] is True
    assert "urgent tasks" in result["message"].lower()
    assert result["model"] == "llama-3.3-70b-versatile"


def test_chat_response_has_required_keys():
    service = _service_with_mock()
    result = service.chat("Help me")

    assert "success" in result
    assert "message" in result
    assert "model" in result


# ── Student context in messages ────────────────────────────────────────────────


def test_chat_includes_student_context_in_messages():
    mock = MockLLMProvider()
    service = _service_with_mock(mock)

    service.chat(
        "Help me prioritize",
        student_context={
            "name": "Pakinam",
            "tasks": [
                {"title": "Database Project", "priority": "urgent"},
                {"title": "Midterm Grades", "priority": "high"},
            ],
        },
    )

    assert mock.last_messages is not None
    system_contents = [m["content"] for m in mock.last_messages if m["role"] == "system"]
    joined = "\n".join(system_contents)

    # Actionable task should be present
    assert "Pakinam" in joined
    assert "Database Project" in joined
    # Grade/completed rows must be filtered out by task_filter
    assert "Midterm Grades" not in joined


def test_chat_does_not_include_context_for_educational_intent():
    """Pure educational questions (no personal pronouns, no context) should
    not add student context to the messages."""
    mock = MockLLMProvider()
    service = _service_with_mock(mock)

    service.chat(
        "What is the pomodoro technique?",
        student_context=None,
    )

    # Should still succeed without any context
    assert mock.last_messages is not None
    user_msgs = [m for m in mock.last_messages if m["role"] == "user"]
    assert len(user_msgs) == 1
    assert "pomodoro" in user_msgs[0]["content"].lower()


# ── Error handling ─────────────────────────────────────────────────────────────


def test_chat_handles_provider_failure():
    service = _service_with_mock(MockLLMProvider(raise_error=True))

    result = service.chat("Hello")

    assert result["success"] is False
    assert "technical difficulties" in result["message"].lower()


def test_chat_handles_runtime_error_from_provider():
    """RuntimeError (both primary and fallback failed) returns safe message."""
    service = _service_with_mock(MockLLMProvider(raise_error=True))

    result = service.chat("Tell me my tasks")

    assert result["success"] is False
    assert result.get("error") is not None


# ── Conversation history ───────────────────────────────────────────────────────


def test_chat_includes_conversation_history():
    mock = MockLLMProvider()
    service = _service_with_mock(mock)

    history = [
        {"role": "user", "content": "Hi"},
        {"role": "assistant", "content": "Hello!"},
    ]
    service.chat("What next?", conversation_history=history)

    roles = [m["role"] for m in mock.last_messages]
    assert "user" in roles
    assert "assistant" in roles


def test_chat_limits_history_to_20_turns():
    mock = MockLLMProvider()
    service = _service_with_mock(mock)

    # 25 turns = 50 messages
    history = [{"role": "user" if i % 2 == 0 else "assistant", "content": f"msg{i}"}
               for i in range(50)]
    service.chat("What now?", conversation_history=history)

    # Last 20 of 50 history messages + system + user = at most 22 messages
    non_system = [m for m in mock.last_messages if m["role"] != "system"]
    assert len(non_system) <= 21  # 20 history + 1 current


# ── Routing metadata ───────────────────────────────────────────────────────────


def test_chat_returns_routing_metadata():
    service = _service_with_mock()

    result = service.chat("my tasks?")

    # routing key should be present for server-side logging
    assert "routing" in result
    assert "intent" in result["routing"]
    assert "used_fallback" in result["routing"]


# ── Quick suggestions ──────────────────────────────────────────────────────────


def test_get_quick_suggestions_with_urgent_context():
    service = _service_with_mock()

    suggestions = service.get_quick_suggestions(
        {"urgent_tasks": True, "upcoming_deadline": True}
    )

    assert len(suggestions) <= 5
    assert suggestions[0] == "What urgent tasks should I do first?"
    assert "Help me prepare for my deadline" in suggestions


def test_get_quick_suggestions_default():
    service = _service_with_mock()
    suggestions = service.get_quick_suggestions()

    assert len(suggestions) <= 5
    assert len(suggestions) > 0


def test_get_quick_suggestions_with_overdue_count():
    service = _service_with_mock()
    context = {
        "personalizationSignals": {"overdueActionableCount": 3}
    }
    suggestions = service.get_quick_suggestions(context)

    assert suggestions[0] == "What urgent tasks should I do first?"


# ── System prompt ──────────────────────────────────────────────────────────────


def test_system_prompt_includes_hallucination_guard():
    prompt = AIChatService._get_system_prompt()
    # Must instruct model NOT to invent data
    assert "never invent" in prompt.lower() or "not available" in prompt.lower()


def test_system_prompt_includes_language_support():
    prompt = AIChatService._get_system_prompt()
    assert "arabic" in prompt.lower()
