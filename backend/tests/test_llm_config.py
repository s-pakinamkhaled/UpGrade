"""
Tests for LLM configuration loading (ai/llm/config.py).

Verifies that:
- All environment variables are read correctly
- Default values are applied when variables are absent
- Boolean flags parse correctly
- API key presence/absence is handled gracefully
"""

import os
import sys

# Add ai/ to path so we can import the llm package
_AI_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "ai"
)
if _AI_PATH not in sys.path:
    sys.path.insert(0, _AI_PATH)

from llm.config import LLMConfig, load_config


def _load_with_env(**overrides):
    """Helper: set env vars, load config, restore env."""
    original = {}
    for key, value in overrides.items():
        original[key] = os.environ.get(key)
        if value is None:
            os.environ.pop(key, None)
        else:
            os.environ[key] = value

    try:
        return load_config()
    finally:
        for key, old_val in original.items():
            if old_val is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = old_val


# ── Default values ─────────────────────────────────────────────────────────────


def test_defaults_applied_when_vars_absent():
    keys_to_clear = [
        "LLM_PROVIDER", "PLAN_PROVIDER", "PLAN_FALLBACK_PROVIDER",
        "CHAT_PROVIDER", "CHAT_FALLBACK_PROVIDER",
        "JUDGE_PROVIDER", "JUDGE_FALLBACK_PROVIDER",
        "PLAN_MODEL", "PLAN_FALLBACK_MODEL",
        "CHAT_MODEL", "CHAT_FALLBACK_MODEL",
        "JUDGE_MODEL", "JUDGE_FALLBACK_MODEL",
        "ENABLE_LLM_JUDGE", "ENABLE_STUDY_PLAN_JUDGE", "ENABLE_CHATBOT_JUDGE",
        "GROQ_API_KEY", "GEMINI_API_KEY",
        "EDUCATIONAL_FALLBACK_PROVIDER", "EDUCATIONAL_FALLBACK_MODEL",
    ]
    cfg = _load_with_env(**{k: None for k in keys_to_clear})

    assert cfg.llm_provider == "groq"
    assert cfg.plan_provider == "groq"
    assert cfg.plan_fallback_provider == "groq"
    assert cfg.chat_provider == "groq"
    assert cfg.chat_fallback_provider == "groq"
    assert cfg.judge_provider == "groq"
    assert cfg.judge_fallback_provider == "groq"
    assert cfg.plan_model == "llama-3.3-70b-versatile"
    assert cfg.plan_fallback_model == "llama-3.1-8b-instant"
    assert cfg.chat_model == "llama-3.3-70b-versatile"
    assert cfg.chat_fallback_model == "llama-3.1-8b-instant"
    assert cfg.judge_model == "llama-3.3-70b-versatile"
    assert cfg.judge_fallback_model == "llama-3.1-8b-instant"
    assert cfg.enable_llm_judge is False
    assert cfg.enable_study_plan_judge is False
    assert cfg.enable_chatbot_judge is False
    assert cfg.groq_api_key is None
    assert cfg.gemini_api_key is None
    assert cfg.educational_fallback_provider is None
    assert cfg.educational_fallback_model is None


# ── Explicit values ────────────────────────────────────────────────────────────


def test_plan_model_read_from_env():
    cfg = _load_with_env(PLAN_MODEL="gemma2-9b-it", PLAN_FALLBACK_MODEL="llama-3.1-8b-instant")
    assert cfg.plan_model == "gemma2-9b-it"
    assert cfg.plan_fallback_model == "llama-3.1-8b-instant"


def test_chat_model_read_from_env():
    cfg = _load_with_env(CHAT_MODEL="mixtral-8x7b-32768", CHAT_FALLBACK_MODEL="llama-3.1-8b-instant")
    assert cfg.chat_model == "mixtral-8x7b-32768"


def test_judge_model_read_from_env():
    cfg = _load_with_env(JUDGE_MODEL="llama-3.1-70b-versatile")
    assert cfg.judge_model == "llama-3.1-70b-versatile"


def test_provider_lowercased():
    cfg = _load_with_env(LLM_PROVIDER="GROQ")
    assert cfg.llm_provider == "groq"
    assert cfg.plan_provider == "groq"
    assert cfg.chat_provider == "groq"
    assert cfg.judge_provider == "groq"


def test_per_feature_providers_override_global_provider():
    cfg = _load_with_env(
        LLM_PROVIDER="groq",
        PLAN_PROVIDER="gemini",
        PLAN_FALLBACK_PROVIDER="groq",
        CHAT_PROVIDER="groq",
        CHAT_FALLBACK_PROVIDER="gemini",
        JUDGE_PROVIDER="gemini",
        JUDGE_FALLBACK_PROVIDER="groq",
    )

    assert cfg.plan_provider == "gemini"
    assert cfg.plan_fallback_provider == "groq"
    assert cfg.chat_provider == "groq"
    assert cfg.chat_fallback_provider == "gemini"
    assert cfg.judge_provider == "gemini"
    assert cfg.judge_fallback_provider == "groq"


def test_groq_api_key_read_from_env():
    cfg = _load_with_env(GROQ_API_KEY="gsk_test_key_123")
    assert cfg.groq_api_key == "gsk_test_key_123"


def test_gemini_api_key_read_from_env():
    cfg = _load_with_env(GEMINI_API_KEY="AIza_test_key")
    assert cfg.gemini_api_key == "AIza_test_key"


# ── Boolean flag parsing ───────────────────────────────────────────────────────


def test_judge_flags_true_values():
    for val in ("true", "True", "TRUE", "1", "yes"):
        cfg = _load_with_env(ENABLE_LLM_JUDGE=val)
        assert cfg.enable_llm_judge is True, f"Expected True for ENABLE_LLM_JUDGE={val!r}"


def test_judge_flags_false_values():
    for val in ("false", "False", "0", "no", ""):
        cfg = _load_with_env(ENABLE_LLM_JUDGE=val)
        assert cfg.enable_llm_judge is False, f"Expected False for ENABLE_LLM_JUDGE={val!r}"


def test_study_plan_judge_flag():
    cfg = _load_with_env(ENABLE_STUDY_PLAN_JUDGE="true")
    assert cfg.enable_study_plan_judge is True


def test_chatbot_judge_flag():
    cfg = _load_with_env(ENABLE_CHATBOT_JUDGE="true")
    assert cfg.enable_chatbot_judge is True


# ── Educational fallback ───────────────────────────────────────────────────────


def test_educational_fallback_provider_and_model():
    cfg = _load_with_env(
        EDUCATIONAL_FALLBACK_PROVIDER="gemini",
        EDUCATIONAL_FALLBACK_MODEL="gemini-1.5-flash",
    )
    assert cfg.educational_fallback_provider == "gemini"
    assert cfg.educational_fallback_model == "gemini-1.5-flash"


def test_empty_educational_fallback_returns_none():
    cfg = _load_with_env(EDUCATIONAL_FALLBACK_PROVIDER="", EDUCATIONAL_FALLBACK_MODEL="")
    assert cfg.educational_fallback_provider is None
    assert cfg.educational_fallback_model is None


# ── LLMConfig dataclass ────────────────────────────────────────────────────────


def test_llmconfig_is_dataclass_with_correct_fields():
    cfg = LLMConfig(
        llm_provider="gemini",
        plan_model="gemini-1.5-pro",
        plan_fallback_model="gemini-1.5-flash",
    )
    assert cfg.llm_provider == "gemini"
    assert cfg.plan_model == "gemini-1.5-pro"
    assert cfg.plan_fallback_model == "gemini-1.5-flash"
    # Other fields should still be at their defaults
    assert cfg.enable_llm_judge is False
