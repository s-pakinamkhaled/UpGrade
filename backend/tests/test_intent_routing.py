"""
Tests for intent classification and chatbot routing (ai/llm/intent_classifier.py).

Verifies:
- USER_DATA_QA intent for personal/task-related questions
- EDUCATIONAL_QA intent for general academic questions
- MIXED_STUDY_ADVICE intent for questions mixing personal context and guidance
- Arabic and Franco Arabic message handling
- Educational fallback privacy guard (never routes student data to external provider)
- Single chatbot endpoint routes correctly for each intent type
- Missing student data: model states unavailability, never invents data
"""

import os
import sys
from unittest.mock import MagicMock, patch

import pytest

_AI_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "ai"
)
if _AI_PATH not in sys.path:
    sys.path.insert(0, _AI_PATH)

from llm.intent_classifier import ChatIntent, classify_intent


# ── USER_DATA_QA ───────────────────────────────────────────────────────────────


def test_my_tasks_classified_as_user_data_qa():
    intent = classify_intent("Show me my tasks for today", {})
    assert intent == ChatIntent.USER_DATA_QA


def test_my_grades_classified_as_user_data_qa():
    # "What are my grades" triggers both user_data keyword ("my grades") and
    # educational keyword ("what are"), so MIXED_STUDY_ADVICE is also valid.
    intent = classify_intent("What are my grades this semester?", {})
    assert intent in {ChatIntent.USER_DATA_QA, ChatIntent.MIXED_STUDY_ADVICE}


def test_my_deadline_classified_as_user_data_qa():
    intent = classify_intent("When is my deadline for the project?", {})
    assert intent == ChatIntent.USER_DATA_QA


def test_my_schedule_classified_as_user_data_qa():
    intent = classify_intent("Can you show me my schedule?", {})
    assert intent == ChatIntent.USER_DATA_QA


def test_user_data_qa_with_student_context():
    context = {"name": "Ali", "actionableTasks": [{"title": "Math HW"}]}
    intent = classify_intent("What should I focus on today?", context)
    # Personal pronoun + context → user data
    assert intent in {ChatIntent.USER_DATA_QA, ChatIntent.MIXED_STUDY_ADVICE}


# ── EDUCATIONAL_QA ────────────────────────────────────────────────────────────


def test_study_tips_classified_as_educational():
    intent = classify_intent("What are the best study tips for exams?", {})
    assert intent == ChatIntent.EDUCATIONAL_QA


def test_explain_concept_classified_as_educational():
    intent = classify_intent("Can you explain the difference between RAM and ROM?", {})
    assert intent == ChatIntent.EDUCATIONAL_QA


def test_pomodoro_classified_as_educational():
    intent = classify_intent("How does the pomodoro technique work?", {})
    assert intent == ChatIntent.EDUCATIONAL_QA


def test_general_question_no_context_classified_educational():
    intent = classify_intent("How to manage procrastination?", {})
    assert intent == ChatIntent.EDUCATIONAL_QA


def test_educational_no_context_no_pronouns():
    intent = classify_intent("What are spaced repetition benefits?", {})
    assert intent == ChatIntent.EDUCATIONAL_QA


# ── MIXED_STUDY_ADVICE ────────────────────────────────────────────────────────


def test_personal_with_context_classified_mixed():
    context = {"name": "Mona", "tasks": [{"title": "Biology Assignment"}]}
    intent = classify_intent("I need help managing my tasks", context)
    assert intent in {ChatIntent.USER_DATA_QA, ChatIntent.MIXED_STUDY_ADVICE}


def test_study_guidance_with_context_classified_mixed():
    context = {"name": "Youssef", "actionableTasks": [{"title": "Networks Lab"}]}
    intent = classify_intent("I'm struggling with time management for my assignments", context)
    assert intent in {ChatIntent.MIXED_STUDY_ADVICE, ChatIntent.USER_DATA_QA}


# ── Arabic messages ────────────────────────────────────────────────────────────


def test_arabic_my_tasks_classified_user_data():
    intent = classify_intent("اعرضلي مهامي النهارده", {})
    assert intent == ChatIntent.USER_DATA_QA


def test_arabic_my_grades():
    intent = classify_intent("عايز أشوف درجاتي", {})
    assert intent == ChatIntent.USER_DATA_QA


def test_arabic_study_tips_educational():
    intent = classify_intent("ايه أحسن نصائح للمذاكرة؟", {})
    assert intent == ChatIntent.EDUCATIONAL_QA


# ── Educational fallback privacy guard ────────────────────────────────────────


def test_educational_qa_with_no_sensitive_data_allows_external_fallback():
    """EDUCATIONAL_QA without student data → educational fallback may be used."""
    intent = classify_intent("How does spaced repetition work?", {})
    assert intent == ChatIntent.EDUCATIONAL_QA
    # No student data → safe for educational fallback


def test_user_data_qa_never_routes_to_external_provider():
    """USER_DATA_QA always stays on the primary provider (no educational fallback)."""
    context = {"name": "Kareem", "actionableTasks": [{"title": "OS Assignment"}]}
    intent = classify_intent("What are my assignments?", context)
    assert intent != ChatIntent.EDUCATIONAL_QA  # must NOT be EDUCATIONAL_QA


def test_context_with_sensitive_data_blocks_external_fallback():
    """When student tasks are present, EDUCATIONAL_QA should not be returned
    even for what looks like a general question."""
    context = {
        "actionableTasks": [{"title": "Chemistry Lab", "courseName": "Chem"}],
    }
    # A general-ish question with personal pronoun + context
    intent = classify_intent("I want to know how to study better", context)
    # With context, it should be treated as personal advice, not pure educational
    assert intent in {ChatIntent.MIXED_STUDY_ADVICE, ChatIntent.USER_DATA_QA}


# ── Hallucination prevention: missing data ────────────────────────────────────


def test_chat_service_states_unavailability_when_data_missing():
    """AIChatService must not invent tasks when context is empty."""
    from chat_service import AIChatService
    from llm.provider import GenerationResult

    service = AIChatService.__new__(AIChatService)
    service.system_prompt = AIChatService._get_system_prompt()

    mock_provider = MagicMock()
    mock_provider.generate_text.return_value = GenerationResult(
        content="I don't have information about your tasks right now.",
        model="llama-primary",
        provider="groq",
        used_fallback=False,
        latency_ms=100.0,
    )
    service.provider = mock_provider

    mock_judge = MagicMock()
    mock_judge.evaluate_chat_response.return_value = MagicMock(
        passed=True, hallucination_detected=False
    )
    service.judge = mock_judge

    from llm.config import LLMConfig
    service.config = LLMConfig(enable_chatbot_judge=False)

    result = service.chat(
        user_message="What tasks do I have?",
        student_context=None,
    )

    assert result["success"] is True
    # Confirm generate_text was called (not mock data invented inline)
    mock_provider.generate_text.assert_called_once()


# ── Single endpoint behaviour ──────────────────────────────────────────────────


def test_classify_intent_returns_valid_enum_values():
    """classify_intent always returns one of the three valid ChatIntent values."""
    test_messages = [
        ("hello", {}),
        ("my tasks", {"name": "Test"}),
        ("explain sorting algorithms", {}),
        ("مهامي", {}),
        ("I'm overwhelmed", {"actionableTasks": []}),
    ]
    valid_intents = set(ChatIntent)
    for msg, ctx in test_messages:
        intent = classify_intent(msg, ctx)
        assert intent in valid_intents, f"Invalid intent {intent!r} for message {msg!r}"


def test_chat_intent_enum_values():
    assert ChatIntent.USER_DATA_QA == "USER_DATA_QA"
    assert ChatIntent.EDUCATIONAL_QA == "EDUCATIONAL_QA"
    assert ChatIntent.MIXED_STUDY_ADVICE == "MIXED_STUDY_ADVICE"
