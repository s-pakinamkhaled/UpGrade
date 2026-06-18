"""
Chatbot endpoint for UpGrade.

Single endpoint that internally:
1. Validates the message
2. Classifies intent (USER_DATA_QA / EDUCATIONAL_QA / MIXED_STUDY_ADVICE)
3. Routes to the appropriate model/provider via AIChatService
4. Returns a response whose schema is identical to the original — no
   frontend changes required.

Intent routing and judge results are logged server-side only; they are not
surfaced in the API response to keep the schema stable.
"""

from __future__ import annotations

import logging
import os
import sys
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.core.security_utils import validate_chat_message

logger = logging.getLogger(__name__)

# ── Path and environment setup ─────────────────────────────────────────────────
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.dirname(current_dir)))
)

backend_env = os.path.join(project_root, "backend", ".env")
ai_env = os.path.join(project_root, "ai", ".env")
load_dotenv(backend_env)
load_dotenv(ai_env)

ai_path = os.path.join(project_root, "ai")
if ai_path not in sys.path:
    sys.path.insert(0, ai_path)

# ── Chat service initialisation ────────────────────────────────────────────────
try:
    from chat_service import AIChatService

    chat_service: Optional[AIChatService] = AIChatService()
    logger.info("[Chat] AIChatService initialised successfully")
except Exception as _init_err:
    logger.warning("[Chat] Could not initialise chat service: %s", _init_err)
    chat_service = None

router = APIRouter(prefix="/chat", tags=["chat"])


# ── Pydantic models (schema unchanged) ────────────────────────────────────────


class ChatMessage(BaseModel):
    role: str  # "user" | "assistant"
    content: str


class ChatRequest(BaseModel):
    message: str
    conversation_history: Optional[List[ChatMessage]] = None
    student_context: Optional[Dict[str, Any]] = None


class ChatResponse(BaseModel):
    success: bool
    message: str
    model: Optional[str] = None
    suggestions: Optional[List[str]] = None
    error: Optional[str] = None


# ── Endpoints ──────────────────────────────────────────────────────────────────


@router.post("/message", response_model=ChatResponse)
async def send_message(request: ChatRequest) -> ChatResponse:
    """Send a message to the AI chatbot and receive a response.

    Internally classifies the request intent and routes to the appropriate
    model via the configured LLM provider.  The response schema is unchanged.
    """
    if not chat_service:
        raise HTTPException(status_code=503, detail="Chat service is not available")

    message_error = validate_chat_message(request.message)
    if message_error:
        raise HTTPException(status_code=400, detail=message_error)

    try:
        history = (
            [{"role": m.role, "content": m.content} for m in request.conversation_history]
            if request.conversation_history
            else None
        )

        result = chat_service.chat(
            user_message=request.message,
            conversation_history=history,
            student_context=request.student_context,
        )

        # Log routing metadata server-side without exposing it in the response
        routing = result.pop("routing", {})
        if routing:
            logger.info(
                "[Chat] intent=%s provider=%s model=%s used_fallback=%s latency_ms=%s",
                routing.get("intent", "unknown"),
                routing.get("provider", "unknown"),
                result.get("model", "unknown"),
                routing.get("used_fallback", False),
                routing.get("latency_ms", 0),
            )

        suggestions = chat_service.get_quick_suggestions(request.student_context)

        return ChatResponse(
            success=result.get("success", False),
            message=result.get("message", ""),
            model=result.get("model"),
            suggestions=suggestions,
            error=result.get("error"),
        )

    except Exception as exc:
        logger.error("[Chat] endpoint error: %s", type(exc).__name__)
        raise HTTPException(status_code=500, detail=f"Chat service error: {str(exc)}")


@router.get("/suggestions")
async def get_suggestions(
    has_urgent_tasks: bool = False,
    has_upcoming_deadline: bool = False,
):
    """Return contextual suggestion chips for the chat UI."""
    if not chat_service:
        return {
            "suggestions": [
                "What should I study now?",
                "Help me prioritize my tasks",
                "I'm feeling overwhelmed",
            ]
        }

    context = {
        "urgent_tasks": has_urgent_tasks,
        "upcoming_deadline": has_upcoming_deadline,
    }
    return {"suggestions": chat_service.get_quick_suggestions(context)}


@router.get("/health")
async def chat_health():
    """Check chat service availability."""
    if not chat_service:
        return {"status": "unavailable", "service": "none"}

    cfg = getattr(chat_service, "config", None)
    return {
        "status": "ok",
        "service": cfg.chat_model if cfg else "llama-3.3-70b-versatile",
        "provider": cfg.llm_provider if cfg else "groq",
        "fallback": cfg.chat_fallback_model if cfg else "llama-3.1-8b-instant",
    }
