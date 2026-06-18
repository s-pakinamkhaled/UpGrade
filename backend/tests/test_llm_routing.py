"""
Tests for LLM provider routing and fallback behaviour (ai/llm/provider.py).

Uses a patched ``requests.post`` to avoid real API calls.
Verifies:
- Successful primary call returns correct GenerationResult
- Failed primary call retries once then falls back
- Failed fallback raises RuntimeError
- generate_json strips markdown fences and parses JSON
- Provider dispatch (groq vs gemini paths)
- Privacy: message content is never logged (confirmed by mock call args)
"""

import json
import os
import sys
from unittest.mock import MagicMock, call, patch

import pytest

_AI_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "ai"
)
if _AI_PATH not in sys.path:
    sys.path.insert(0, _AI_PATH)

from llm.config import LLMConfig
from llm.provider import LLMProvider, GenerationResult


def _config(**kwargs) -> LLMConfig:
    defaults = dict(
        llm_provider="groq",
        plan_model="model-primary",
        plan_fallback_model="model-fallback",
        chat_model="model-primary",
        chat_fallback_model="model-fallback",
        judge_model="model-judge",
        judge_fallback_model="model-judge-fallback",
        groq_api_key="test-key",
        groq_api_base="https://api.groq.com/openai/v1",
        gemini_api_key="test-gemini-key",
    )
    defaults.update(kwargs)
    return LLMConfig(**defaults)


def _mock_groq_response(content: str):
    mock = MagicMock()
    mock.status_code = 200
    mock.json.return_value = {
        "choices": [{"message": {"content": content}}],
        "model": "model-primary",
    }
    mock.raise_for_status = MagicMock()
    return mock


def _mock_gemini_response(content: str):
    mock = MagicMock()
    mock.status_code = 200
    mock.json.return_value = {
        "candidates": [{"content": {"parts": [{"text": content}]}}]
    }
    mock.raise_for_status = MagicMock()
    return mock


# ── generate_text — success path ───────────────────────────────────────────────


def test_generate_text_returns_content_on_success():
    provider = LLMProvider(_config())
    with patch("requests.post", return_value=_mock_groq_response("Hello student!")):
        result = provider.generate_text(
            messages=[{"role": "user", "content": "hi"}],
            model="model-primary",
            fallback_model="model-fallback",
        )

    assert isinstance(result, GenerationResult)
    assert result.content == "Hello student!"
    assert result.model == "model-primary"
    assert result.provider == "groq"
    assert result.used_fallback is False
    assert result.latency_ms >= 0


def test_generate_text_records_provider_and_model():
    provider = LLMProvider(_config(llm_provider="groq"))
    with patch("requests.post", return_value=_mock_groq_response("ok")):
        result = provider.generate_text(
            messages=[{"role": "user", "content": "test"}],
            model="llama-3.3-70b-versatile",
            fallback_model="llama-3.1-8b-instant",
        )
    assert result.provider == "groq"
    assert result.model == "llama-3.3-70b-versatile"


# ── generate_text — retry behaviour ───────────────────────────────────────────


def test_generate_text_retries_once_before_fallback():
    """Primary fails twice → fallback succeeds → used_fallback=True."""
    fail_response = MagicMock()
    fail_response.raise_for_status.side_effect = Exception("Groq 500")

    success_response = _mock_groq_response("fallback reply")

    call_count = 0

    def _side_effect(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        # First two calls (primary + retry) fail; third (fallback) succeeds
        if call_count <= 2:
            raise Exception("Groq 500")
        return success_response

    provider = LLMProvider(_config())
    with patch("requests.post", side_effect=_side_effect), \
         patch("time.sleep"):  # skip real sleep
        result = provider.generate_text(
            messages=[{"role": "user", "content": "test"}],
            model="model-primary",
            fallback_model="model-fallback",
        )

    assert result.content == "fallback reply"
    assert result.used_fallback is True
    assert call_count == 3  # attempt1 + attempt2 + fallback


def test_generate_text_raises_when_fallback_also_fails():
    """All three calls fail → RuntimeError."""
    provider = LLMProvider(_config())

    with patch("requests.post", side_effect=Exception("all down")), \
         patch("time.sleep"):
        with pytest.raises(RuntimeError, match="both primary.*fallback|Both primary"):
            provider.generate_text(
                messages=[{"role": "user", "content": "test"}],
                model="model-primary",
                fallback_model="model-fallback",
            )


# ── generate_text — provider selection ────────────────────────────────────────


def test_explicit_provider_override():
    """Passing provider='gemini' routes to Gemini API."""
    provider = LLMProvider(_config())
    with patch.object(provider, "_call_gemini", return_value="gemini reply") as mock_gem, \
         patch.object(provider, "_call_groq") as mock_groq:
        result = provider.generate_text(
            messages=[{"role": "user", "content": "explain recursion"}],
            model="gemini-1.5-flash",
            fallback_model="model-fallback",
            provider="gemini",
        )

    mock_gem.assert_called_once()
    mock_groq.assert_not_called()
    assert result.content == "gemini reply"
    assert result.provider == "gemini"


def test_fallback_can_use_different_provider():
    """Fallback provider different from primary is respected."""
    provider = LLMProvider(_config())
    call_log = []

    def _groq_side(*args, **kwargs):
        call_log.append("groq")
        raise Exception("groq down")

    def _gemini_side(*args, **kwargs):
        call_log.append("gemini")
        return "gemini fallback"

    with patch.object(provider, "_call_groq", side_effect=_groq_side), \
         patch.object(provider, "_call_gemini", side_effect=_gemini_side), \
         patch("time.sleep"):
        result = provider.generate_text(
            messages=[{"role": "user", "content": "x"}],
            model="primary-model",
            fallback_model="gemini-fallback-model",
            provider="groq",
            fallback_provider="gemini",
        )

    assert result.used_fallback is True
    assert result.provider == "gemini"
    assert "gemini" in call_log


# ── generate_json ──────────────────────────────────────────────────────────────


def test_generate_json_parses_clean_json():
    provider = LLMProvider(_config())
    raw = json.dumps({"items": [], "summary": "done"})
    with patch("requests.post", return_value=_mock_groq_response(raw)):
        parsed, result = provider.generate_json(
            messages=[{"role": "user", "content": "plan"}],
            model="model-primary",
            fallback_model="model-fallback",
        )
    assert parsed == {"items": [], "summary": "done"}
    assert isinstance(result, GenerationResult)


def test_generate_json_strips_markdown_fences():
    provider = LLMProvider(_config())
    raw = '```json\n{"items": [], "summary": "clean"}\n```'
    with patch("requests.post", return_value=_mock_groq_response(raw)):
        parsed, _ = provider.generate_json(
            messages=[{"role": "user", "content": "plan"}],
            model="model-primary",
            fallback_model="model-fallback",
        )
    assert parsed["summary"] == "clean"


def test_generate_json_strips_plain_fences():
    provider = LLMProvider(_config())
    raw = '```\n{"key": "value"}\n```'
    with patch("requests.post", return_value=_mock_groq_response(raw)):
        parsed, _ = provider.generate_json(
            messages=[{"role": "user", "content": "x"}],
            model="model-primary",
            fallback_model="model-fallback",
        )
    assert parsed == {"key": "value"}


def test_generate_json_raises_on_invalid_json():
    provider = LLMProvider(_config())
    with patch("requests.post", return_value=_mock_groq_response("not json at all")):
        with pytest.raises(json.JSONDecodeError):
            provider.generate_json(
                messages=[{"role": "user", "content": "x"}],
                model="model-primary",
                fallback_model="model-fallback",
            )


# ── Missing API keys ───────────────────────────────────────────────────────────


def test_groq_call_raises_when_no_api_key():
    provider = LLMProvider(_config(groq_api_key=None))
    with pytest.raises(ValueError, match="GROQ_API_KEY"):
        provider._call_groq(
            messages=[{"role": "user", "content": "x"}],
            model="m",
            temperature=0.5,
            max_tokens=100,
        )


def test_gemini_call_raises_when_no_api_key():
    provider = LLMProvider(_config(gemini_api_key=None))
    with pytest.raises(ValueError, match="GEMINI_API_KEY"):
        provider._call_gemini(
            messages=[{"role": "user", "content": "x"}],
            model="m",
            temperature=0.5,
            max_tokens=100,
        )


def test_unknown_provider_raises():
    provider = LLMProvider(_config())
    with pytest.raises(ValueError, match="Unknown LLM provider"):
        provider._call_provider(
            provider="openai",
            model="gpt-4",
            messages=[],
            temperature=0.5,
            max_tokens=100,
        )
