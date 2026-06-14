import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(
    0,
    os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "ai"),
)

from chat_service import AIChatService


class MockGroqClient:
    def __init__(self, response=None, raise_error=False):
        self.response = response or {
            "choices": [{"message": {"content": "Focus on your urgent tasks first."}}],
            "model": "llama-3.3-70b-versatile",
            "usage": {"total_tokens": 42},
        }
        self.raise_error = raise_error
        self.last_messages = None

    def chat_completion(self, messages, **kwargs):
        if self.raise_error:
            raise RuntimeError("Groq unavailable")
        self.last_messages = messages
        return self.response


def _service_with_mock(client=None):
    service = AIChatService.__new__(AIChatService)
    service.client = client or MockGroqClient()
    service.system_prompt = AIChatService._get_system_prompt(service)
    return service


def test_chat_returns_success_message():
    service = _service_with_mock()

    result = service.chat("What should I study now?")

    assert result["success"] is True
    assert "urgent tasks" in result["message"].lower()
    assert result["model"] == "llama-3.3-70b-versatile"


def test_chat_includes_student_context_in_messages():
    mock = MockGroqClient()
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

    system_contents = [m["content"] for m in mock.last_messages if m["role"] == "system"]
    joined = "\n".join(system_contents)
    assert "Pakinam" in joined
    assert "Database Project" in joined
    assert "Midterm Grades" not in joined


def test_chat_handles_groq_failure():
    service = _service_with_mock(MockGroqClient(raise_error=True))

    result = service.chat("Hello")

    assert result["success"] is False
    assert "technical difficulties" in result["message"].lower()


def test_chat_handles_empty_choices():
    service = _service_with_mock(MockGroqClient(response={"choices": []}))

    result = service.chat("Hello")

    assert result["success"] is False


def test_get_quick_suggestions_with_urgent_context():
    service = _service_with_mock()

    suggestions = service.get_quick_suggestions(
        {"urgent_tasks": True, "upcoming_deadline": True}
    )

    assert len(suggestions) <= 5
    assert suggestions[0] == "What urgent tasks should I do first?"
    assert "Help me prepare for my deadline" in suggestions
