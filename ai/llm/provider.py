"""
Unified LLM provider abstraction for UpGrade.

Supports Groq (OpenAI-compatible) and Google Gemini via raw REST calls so that
no extra Python packages are required beyond ``requests``.

Retry / fallback strategy
--------------------------
1. Try primary model on the configured provider.
2. If that fails:
   - 429 (rate-limit): wait for the Retry-After header (or exponential backoff)
     before retrying.  Non-retriable status codes (4xx except 429) are NOT
     retried — they surface immediately to fall back.
   - Other errors: wait 2 s and retry once.
3. If both primary attempts fail, try the fallback model / provider.
4. If fallback also fails, raise ``RuntimeError`` with a clean message.

Logging
-------
- Logs: provider, model, routing decision, fallback usage, latency (ms),
  HTTP status codes on failure.
- Does NOT log message content, prompts, or student data.
"""

from __future__ import annotations

import json
import logging
import time
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple

import requests
from requests.exceptions import HTTPError, RequestException, Timeout

from .config import LLMConfig

logger = logging.getLogger(__name__)

# Seconds to wait between attempts when the server returns a transient error.
_BASE_RETRY_DELAY_S = 2.0
# Maximum backoff cap so we never wait more than this.
_MAX_RETRY_DELAY_S = 30.0

# HTTP status codes that are worth retrying (transient / rate-limited).
_RETRIABLE_STATUS = {429, 500, 502, 503, 504}
# HTTP status codes that are NOT worth retrying (permanent client errors).
_PERMANENT_ERROR_STATUS = {400, 401, 403, 404, 422}


@dataclass
class GenerationResult:
    """Metadata about a completed LLM generation."""

    content: str
    model: str
    provider: str
    used_fallback: bool = False
    latency_ms: float = 0.0


class LLMProvider:
    """
    Provider abstraction supporting Groq and Gemini with retry + fallback.

    Usage::

        config = load_config()
        provider = LLMProvider(config)

        # Text generation
        result = provider.generate_text(
            messages=[{"role": "user", "content": "..."}],
            model=config.chat_model,
            fallback_model=config.chat_fallback_model,
        )

        # JSON generation (strips markdown fences, parses JSON)
        parsed, result = provider.generate_json(
            messages=messages,
            model=config.plan_model,
            fallback_model=config.plan_fallback_model,
        )
    """

    def __init__(self, config: LLMConfig) -> None:
        self.config = config

    # ── Low-level provider calls ───────────────────────────────────────────────

    def _call_groq(
        self,
        messages: List[Dict[str, str]],
        model: str,
        temperature: float,
        max_tokens: int,
    ) -> str:
        if not self.config.groq_api_key:
            raise ValueError("GROQ_API_KEY is not configured")

        headers = {
            "Authorization": f"Bearer {self.config.groq_api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": False,
        }

        response = requests.post(
            f"{self.config.groq_api_base}/chat/completions",
            headers=headers,
            json=payload,
            timeout=90,
        )
        if not response.ok:
            # Attach the status code and first 200 chars of body so callers can
            # make smart retry decisions without re-reading the response.
            err = HTTPError(
                f"HTTP {response.status_code} from Groq: "
                f"{response.text[:200].strip()}",
                response=response,
            )
            raise err
        data = response.json()
        return data["choices"][0]["message"]["content"]

    def _call_gemini(
        self,
        messages: List[Dict[str, str]],
        model: str,
        temperature: float,
        max_tokens: int,
    ) -> str:
        if not self.config.gemini_api_key:
            raise ValueError("GEMINI_API_KEY is not configured")

        # Convert OpenAI-style roles to Gemini format
        contents: List[Dict] = []
        system_parts: List[Dict] = []

        for msg in messages:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            if role == "system":
                system_parts.append({"text": content})
            elif role == "user":
                contents.append({"role": "user", "parts": [{"text": content}]})
            elif role == "assistant":
                contents.append({"role": "model", "parts": [{"text": content}]})

        payload: Dict[str, Any] = {
            "contents": contents,
            "generationConfig": {
                "temperature": temperature,
                "maxOutputTokens": max_tokens,
            },
        }
        if system_parts:
            payload["systemInstruction"] = {"parts": system_parts}

        url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/"
            f"{model}:generateContent?key={self.config.gemini_api_key}"
        )
        response = requests.post(url, json=payload, timeout=90)
        if not response.ok:
            err = HTTPError(
                f"HTTP {response.status_code} from Gemini: "
                f"{response.text[:200].strip()}",
                response=response,
            )
            raise err
        data = response.json()
        return data["candidates"][0]["content"]["parts"][0]["text"]

    def _call_provider(
        self,
        provider: str,
        model: str,
        messages: List[Dict[str, str]],
        temperature: float,
        max_tokens: int,
    ) -> str:
        """Dispatch to the appropriate provider implementation."""
        if provider == "groq":
            return self._call_groq(messages, model, temperature, max_tokens)
        if provider == "gemini":
            return self._call_gemini(messages, model, temperature, max_tokens)
        raise ValueError(f"Unknown LLM provider: '{provider}'")

    # ── Public generation methods ──────────────────────────────────────────────

    # ── Retry helpers ─────────────────────────────────────────────────────────

    @staticmethod
    def _http_status(exc: Exception) -> Optional[int]:
        """Extract the HTTP status code from an HTTPError, or None."""
        resp = getattr(exc, "response", None)
        if resp is not None:
            return getattr(resp, "status_code", None)
        return None

    @staticmethod
    def _retry_after(exc: Exception) -> float:
        """Return the Retry-After delay in seconds (capped at _MAX_RETRY_DELAY_S)."""
        resp = getattr(exc, "response", None)
        if resp is None:
            return _BASE_RETRY_DELAY_S
        raw = resp.headers.get("Retry-After") or resp.headers.get("retry-after")
        if raw is not None:
            try:
                return min(float(raw), _MAX_RETRY_DELAY_S)
            except ValueError:
                pass
        return _BASE_RETRY_DELAY_S

    @staticmethod
    def _is_retriable(exc: Exception) -> bool:
        """Return True if the error is worth retrying."""
        status = LLMProvider._http_status(exc)
        if status is None:
            # Network error, timeout — always retry.
            return True
        if status in _PERMANENT_ERROR_STATUS:
            return False
        return status in _RETRIABLE_STATUS

    # ── Public generation methods ──────────────────────────────────────────────

    def generate_text(
        self,
        messages: List[Dict[str, str]],
        model: str,
        fallback_model: str,
        provider: Optional[str] = None,
        fallback_provider: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 500,
    ) -> GenerationResult:
        """Generate text with smart retry + fallback.

        Retry strategy
        ~~~~~~~~~~~~~~
        - On a 429 (rate-limit): honour the ``Retry-After`` response header or
          apply exponential backoff before the second attempt.
        - On non-retriable 4xx errors (401, 403, 404, 422): skip the retry and
          fall back immediately — retrying a 401 is pointless.
        - On transient 5xx / network errors: wait ``_BASE_RETRY_DELAY_S`` then retry.

        Args:
            messages:          OpenAI-style message list.
            model:             Primary model name.
            fallback_model:    Model to try after primary exhausts retries.
            provider:          Primary provider; defaults to ``config.llm_provider``.
            fallback_provider: Provider for fallback model; defaults to primary.
            temperature:       Sampling temperature.
            max_tokens:        Maximum output tokens.

        Returns:
            ``GenerationResult`` with content + routing metadata.

        Raises:
            RuntimeError: when both primary and fallback models fail.
        """
        effective_provider = provider or self.config.llm_provider
        effective_fallback_provider = fallback_provider or effective_provider

        start = time.monotonic()

        # ── Primary model — up to 2 attempts ──────────────────────────────────
        last_error: Exception = RuntimeError("No attempts made")
        for attempt in range(2):
            try:
                content = self._call_provider(
                    effective_provider, model, messages, temperature, max_tokens
                )
                latency_ms = (time.monotonic() - start) * 1000
                logger.info(
                    "[LLM] provider=%s model=%s attempt=%d latency_ms=%.0f used_fallback=False",
                    effective_provider,
                    model,
                    attempt + 1,
                    latency_ms,
                )
                return GenerationResult(
                    content=content,
                    model=model,
                    provider=effective_provider,
                    used_fallback=False,
                    latency_ms=latency_ms,
                )
            except Exception as exc:
                last_error = exc
                status = self._http_status(exc)
                logger.warning(
                    "[LLM] provider=%s model=%s attempt=%d failed: %s (HTTP %s)",
                    effective_provider,
                    model,
                    attempt + 1,
                    type(exc).__name__,
                    status if status else "n/a",
                )

                if attempt == 0:
                    if not self._is_retriable(exc):
                        # Permanent error (bad key, bad request) — skip retry.
                        logger.warning(
                            "[LLM] HTTP %s is non-retriable, skipping retry for %s",
                            status,
                            model,
                        )
                        break
                    # Wait with backoff before the second attempt.
                    delay = self._retry_after(exc) if status == 429 else _BASE_RETRY_DELAY_S
                    logger.info("[LLM] waiting %.1fs before retry (status=%s)", delay, status)
                    time.sleep(delay)

        # ── Fallback model — single attempt ───────────────────────────────────
        logger.warning(
            "[LLM] primary exhausted; falling back to provider=%s model=%s",
            effective_fallback_provider,
            fallback_model,
        )
        try:
            # If rate-limited on the same provider, back off before the fallback
            # attempt too — hitting the fallback immediately on a 429 just burns
            # the same rate-limit budget.
            primary_status = self._http_status(last_error)
            if primary_status == 429 and effective_fallback_provider == effective_provider:
                delay = self._retry_after(last_error)
                logger.info(
                    "[LLM] rate-limited on %s; waiting %.1fs before fallback",
                    effective_provider,
                    delay,
                )
                time.sleep(delay)

            content = self._call_provider(
                effective_fallback_provider,
                fallback_model,
                messages,
                temperature,
                max_tokens,
            )
            latency_ms = (time.monotonic() - start) * 1000
            logger.info(
                "[LLM] provider=%s model=%s latency_ms=%.0f used_fallback=True",
                effective_fallback_provider,
                fallback_model,
                latency_ms,
            )
            return GenerationResult(
                content=content,
                model=fallback_model,
                provider=effective_fallback_provider,
                used_fallback=True,
                latency_ms=latency_ms,
            )
        except Exception as exc:
            status = self._http_status(exc)
            logger.error(
                "[LLM] fallback provider=%s model=%s failed: %s (HTTP %s)",
                effective_fallback_provider,
                fallback_model,
                type(exc).__name__,
                status if status else "n/a",
            )
            raise RuntimeError(
                f"Both primary ({model}) and fallback ({fallback_model}) models failed. "
                f"Last primary error: {last_error} | Last fallback error: {exc}"
            ) from exc

    def generate_json(
        self,
        messages: List[Dict[str, str]],
        model: str,
        fallback_model: str,
        provider: Optional[str] = None,
        fallback_provider: Optional[str] = None,
        temperature: float = 0.4,
        max_tokens: int = 3000,
    ) -> Tuple[Dict[str, Any], GenerationResult]:
        """Generate text and parse as JSON with retry + fallback.

        Strips markdown code fences before parsing so models that wrap JSON in
        triple-backtick blocks still work.

        Returns:
            ``(parsed_dict, GenerationResult)`` on success.

        Raises:
            json.JSONDecodeError: if the output cannot be parsed as JSON even
                after all retry/fallback attempts.
            RuntimeError: if all provider calls fail.
        """
        result = self.generate_text(
            messages=messages,
            model=model,
            fallback_model=fallback_model,
            provider=provider,
            fallback_provider=fallback_provider,
            temperature=temperature,
            max_tokens=max_tokens,
        )

        content = result.content.strip()

        # Strip leading fence (```json or ```)
        if content.startswith("```"):
            content = content.split("\n", 1)[-1]
        # Strip trailing fence
        if content.endswith("```"):
            content = content.rsplit("```", 1)[0]
        content = content.strip()

        parsed: Dict[str, Any] = json.loads(content)
        return parsed, result
