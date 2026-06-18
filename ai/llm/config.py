"""
Environment-based LLM configuration for UpGrade.

All model/provider settings are read from environment variables so that
deployments can swap models without code changes.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class LLMConfig:
    # ── Provider ──────────────────────────────────────────────────────────────
    llm_provider: str = "groq"

    # ── Plan models ───────────────────────────────────────────────────────────
    plan_model: str = "llama-3.3-70b-versatile"
    plan_fallback_model: str = "llama-3.1-8b-instant"

    # ── Chat models ───────────────────────────────────────────────────────────
    chat_model: str = "llama-3.3-70b-versatile"
    chat_fallback_model: str = "llama-3.1-8b-instant"

    # ── Judge models ──────────────────────────────────────────────────────────
    judge_model: str = "llama-3.3-70b-versatile"
    judge_fallback_model: str = "llama-3.1-8b-instant"

    # ── Educational fallback (optional; Gemini only when no student data) ─────
    educational_fallback_provider: Optional[str] = None
    educational_fallback_model: Optional[str] = None

    # ── API keys and base URLs ─────────────────────────────────────────────────
    groq_api_key: Optional[str] = None
    groq_api_base: str = "https://api.groq.com/openai/v1"
    gemini_api_key: Optional[str] = None

    # ── Judge feature flags ────────────────────────────────────────────────────
    enable_llm_judge: bool = False
    enable_study_plan_judge: bool = False
    enable_chatbot_judge: bool = False


def load_config() -> LLMConfig:
    """Load LLM configuration from environment variables.

    Reads all relevant env vars and returns a validated ``LLMConfig``
    instance. Missing optional variables fall back to sensible defaults so
    the system degrades gracefully rather than failing hard.
    """

    def _bool(key: str, default: bool = False) -> bool:
        return os.getenv(key, str(default)).strip().lower() in {"true", "1", "yes"}

    return LLMConfig(
        llm_provider=os.getenv("LLM_PROVIDER", "groq").strip().lower(),
        # Plan models
        plan_model=os.getenv("PLAN_MODEL", "llama-3.3-70b-versatile"),
        plan_fallback_model=os.getenv("PLAN_FALLBACK_MODEL", "llama-3.1-8b-instant"),
        # Chat models
        chat_model=os.getenv("CHAT_MODEL", "llama-3.3-70b-versatile"),
        chat_fallback_model=os.getenv("CHAT_FALLBACK_MODEL", "llama-3.1-8b-instant"),
        # Judge models
        judge_model=os.getenv("JUDGE_MODEL", "llama-3.3-70b-versatile"),
        judge_fallback_model=os.getenv("JUDGE_FALLBACK_MODEL", "llama-3.1-8b-instant"),
        # Educational fallback
        educational_fallback_provider=os.getenv("EDUCATIONAL_FALLBACK_PROVIDER") or None,
        educational_fallback_model=os.getenv("EDUCATIONAL_FALLBACK_MODEL") or None,
        # API keys
        groq_api_key=os.getenv("GROQ_API_KEY") or None,
        groq_api_base=os.getenv("GROQ_API_BASE", "https://api.groq.com/openai/v1"),
        gemini_api_key=os.getenv("GEMINI_API_KEY") or None,
        # Judge flags
        enable_llm_judge=_bool("ENABLE_LLM_JUDGE"),
        enable_study_plan_judge=_bool("ENABLE_STUDY_PLAN_JUDGE"),
        enable_chatbot_judge=_bool("ENABLE_CHATBOT_JUDGE"),
    )
