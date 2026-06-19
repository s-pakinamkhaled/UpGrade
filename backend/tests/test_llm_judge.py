"""
Tests for LLM-as-a-Judge (ai/llm/judge.py).

Verifies:
- Judge returns pass-through when disabled
- Judge parses structured JSON output correctly
- Judge selects a different model than the generator when possible
- Hallucination flag is surfaced correctly
- Judge gracefully handles provider errors
- Context summary does not include internal IDs
- All public fields are present in JudgeResult
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

from llm.config import LLMConfig
from llm.judge import JudgeResult, LLMJudge
from llm.provider import GenerationResult, LLMProvider


def _config(**kwargs) -> LLMConfig:
    defaults = dict(
        llm_provider="groq",
        chat_model="llama-primary",
        chat_fallback_model="llama-fallback",
        judge_model="judge-model",
        judge_fallback_model="judge-fallback",
        groq_api_key="test-key",
        groq_api_base="https://api.groq.com/openai/v1",
        enable_llm_judge=True,
        enable_study_plan_judge=True,
        enable_chatbot_judge=True,
    )
    defaults.update(kwargs)
    return LLMConfig(**defaults)


def _judge_with_mock_provider(json_response: dict, raise_error: bool = False) -> LLMJudge:
    """Build a LLMJudge whose underlying provider returns a fixed JSON string."""
    import json as _json

    cfg = _config()
    provider = LLMProvider(cfg)

    if raise_error:
        provider.generate_json = MagicMock(side_effect=RuntimeError("judge provider down"))
    else:
        gen_result = GenerationResult(
            content=_json.dumps(json_response),
            model="judge-model",
            provider="groq",
            used_fallback=False,
        )
        provider.generate_json = MagicMock(return_value=(_json.dumps(json_response), gen_result))

        # generate_json actually returns (dict, GenerationResult) not (str, GenerationResult)
        provider.generate_json = MagicMock(return_value=(json_response, gen_result))

    return LLMJudge(cfg, provider)


# ── Pass-through when judge is disabled ───────────────────────────────────────


def test_chatbot_judge_disabled_returns_passthrough():
    cfg = _config(enable_chatbot_judge=False)
    provider = LLMProvider(cfg)
    judge = LLMJudge(cfg, provider)

    result = judge.evaluate_chat_response(
        user_message="how do I study?",
        ai_response="Use spaced repetition.",
    )

    assert result.passed is True
    assert result.hallucination_detected is False
    assert result.recommended_action == "accept"
    assert result.judge_model == ""
    assert "disabled" in result.reasoning.lower()


def test_study_plan_judge_disabled_returns_passthrough():
    cfg = _config(enable_study_plan_judge=False)
    provider = LLMProvider(cfg)
    judge = LLMJudge(cfg, provider)

    result = judge.evaluate_study_plan(
        plan_items=[],
        input_tasks=[],
        summary="empty plan",
    )

    assert result.passed is True
    assert result.recommended_action == "accept"


# ── Structured JSON evaluation parsing ────────────────────────────────────────


def test_chatbot_judge_parses_passed_result():
    judge_json = {
        "passed": True,
        "hallucination_detected": False,
        "score": 0.95,
        "issues": [],
        "recommended_action": "accept",
        "reasoning": "All tasks mentioned are real.",
    }
    judge = _judge_with_mock_provider(judge_json)

    result = judge.evaluate_chat_response(
        user_message="What should I study today?",
        ai_response="Focus on your Database Project due Friday.",
        student_context={
            "name": "Ahmed",
            "actionableTasks": [{"title": "Database Project", "courseName": "DB"}],
        },
    )

    assert result.passed is True
    assert result.hallucination_detected is False
    assert result.score == 0.95
    assert result.recommended_action == "accept"
    assert result.judge_model == "judge-model"


def test_chatbot_judge_parses_failed_result():
    judge_json = {
        "passed": False,
        "hallucination_detected": True,
        "score": 0.2,
        "issues": ["Mentioned 'AI Assignment' which is not in context"],
        "recommended_action": "reject",
        "reasoning": "Hallucinated a task.",
    }
    judge = _judge_with_mock_provider(judge_json)

    result = judge.evaluate_chat_response(
        user_message="What do I need to do?",
        ai_response="Work on your AI Assignment.",
    )

    assert result.passed is False
    assert result.hallucination_detected is True
    assert result.score == 0.2
    assert result.recommended_action == "reject"
    assert len(result.issues) == 1


def test_study_plan_judge_parses_result():
    judge_json = {
        "passed": True,
        "hallucination_detected": False,
        "score": 0.88,
        "issues": [],
        "recommended_action": "accept",
        "reasoning": "All plan tasks correspond to input tasks.",
    }
    judge = _judge_with_mock_provider(judge_json)

    result = judge.evaluate_study_plan(
        plan_items=[{"taskTitle": "Math HW", "suggestedDate": "2025-01-20", "priority": "high"}],
        input_tasks=[{"title": "Math HW", "courseName": "Math", "deadline": "2025-01-21"}],
        summary="Focus on math first.",
    )

    assert result.passed is True
    assert result.score == 0.88


def test_study_plan_judge_receives_generator_prompts_and_schedule_rules():
    judge_json = {
        "passed": True,
        "hallucination_detected": False,
        "score": 0.9,
        "issues": [],
        "recommended_action": "accept",
        "reasoning": "Schedule respects prompt constraints.",
    }
    judge = _judge_with_mock_provider(judge_json)

    judge.evaluate_study_plan(
        plan_items=[
            {
                "taskTitle": "Final Submission",
                "suggestedDate": "2026-06-20",
                "suggestedTime": "09:00 - 11:00",
                "hoursNeeded": 2,
                "priority": "urgent",
            }
        ],
        input_tasks=[
            {
                "title": "Final Submission",
                "courseName": "Senior Project",
                "deadline": "2026-06-20T23:59:00",
                "status": "pending",
                "estimatedMinutes": 120,
            }
        ],
        summary="Finish the final submission before catch-up work.",
        system_prompt="Planner system rules",
        user_prompt="Student daily capacity: 6 hours. Do not exceed it.",
        generator_model="planner-model",
    )

    messages = judge.provider.generate_json.call_args.kwargs["messages"]
    judge_prompt = messages[-1]["content"]
    assert "Planner system rules" in judge_prompt
    assert "Student daily capacity: 6 hours" in judge_prompt
    assert "no pending/in-progress task is scheduled after its deadline" in judge_prompt
    assert "hoursNeeded matches the input estimates" in judge_prompt


# ── JudgeResult fields ─────────────────────────────────────────────────────────


def test_judge_result_has_all_required_fields():
    result = JudgeResult(
        passed=True,
        hallucination_detected=False,
        score=1.0,
        issues=[],
        recommended_action="accept",
        reasoning="ok",
        judge_model="judge-model",
        judge_provider="groq",
    )
    assert hasattr(result, "passed")
    assert hasattr(result, "hallucination_detected")
    assert hasattr(result, "score")
    assert hasattr(result, "issues")
    assert hasattr(result, "recommended_action")
    assert hasattr(result, "reasoning")
    assert hasattr(result, "judge_model")
    assert hasattr(result, "judge_provider")


# ── Model selection ────────────────────────────────────────────────────────────


def test_judge_selects_different_model_from_generator():
    cfg = _config(judge_model="judge-model-A", judge_fallback_model="judge-model-B")
    provider = LLMProvider(cfg)
    judge = LLMJudge(cfg, provider)

    # When generator used judge-model-A, the judge should prefer judge-model-B
    selected = judge._select_judge_model(generator_model="judge-model-A")
    assert selected == "judge-model-B"


def test_judge_uses_primary_when_different_from_generator():
    cfg = _config(judge_model="judge-primary", judge_fallback_model="judge-fallback")
    provider = LLMProvider(cfg)
    judge = LLMJudge(cfg, provider)

    selected = judge._select_judge_model(generator_model="chat-model")
    assert selected == "judge-primary"


# ── Error handling ─────────────────────────────────────────────────────────────


def test_judge_returns_passthrough_on_provider_error():
    judge = _judge_with_mock_provider({}, raise_error=True)

    result = judge.evaluate_chat_response(
        user_message="test",
        ai_response="test response",
    )

    assert result.passed is True  # non-blocking
    assert "error" in result.reasoning.lower()


# ── Privacy: context summary ───────────────────────────────────────────────────


def test_compact_context_summary_excludes_internal_ids():
    cfg = _config()
    judge = LLMJudge(cfg, LLMProvider(cfg))

    context = {
        "name": "Sara",
        "actionableTasks": [
            {
                "id": "internal-uuid-12345",  # must NOT appear in summary
                "title": "Physics Lab Report",
                "courseName": "Physics",
            }
        ],
    }

    summary = judge._compact_context_summary(context)

    assert "internal-uuid-12345" not in summary
    assert "Sara" in summary
    assert "Physics Lab Report" in summary


def test_compact_context_summary_handles_empty_context():
    cfg = _config()
    judge = LLMJudge(cfg, LLMProvider(cfg))

    summary = judge._compact_context_summary(None)
    assert "No student context" in summary

    summary = judge._compact_context_summary({})
    assert summary  # non-empty string
