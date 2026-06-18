"""
AI Chat Service for UpGrade.

Handles student chatbot conversations with:
- Intent classification (USER_DATA_QA / EDUCATIONAL_QA / MIXED_STUDY_ADVICE)
- Configurable model/provider routing via environment variables
- Optional educational fallback to Gemini when no sensitive student data is present
- Retry + fallback on provider failures
- Optional LLM-as-a-Judge evaluation
- Privacy-safe context building (no internal IDs sent to external providers)
"""

from __future__ import annotations

import logging
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv

# Resolve and load env files relative to the ai/ root so this module works
# whether imported directly or through the backend's sys.path insertion.
_AI_ROOT = Path(__file__).resolve().parent
load_dotenv(_AI_ROOT / ".env")

from llm.config import LLMConfig, load_config
from llm.intent_classifier import ChatIntent, classify_intent
from llm.judge import LLMJudge
from llm.provider import GenerationResult, LLMProvider
from task_filter import filter_real_tasks as _filter_real_tasks

logger = logging.getLogger(__name__)


class AIChatService:
    """Service for handling AI chat conversations with students."""

    def __init__(self) -> None:
        self.config: LLMConfig = load_config()
        self.provider: LLMProvider = LLMProvider(self.config)
        self.judge: LLMJudge = LLMJudge(self.config, self.provider)
        self.system_prompt: str = self._get_system_prompt()
        logger.info(
            "[ChatService] init provider=%s chat_model=%s",
            self.config.llm_provider,
            self.config.chat_model,
        )

    # ── Public API ─────────────────────────────────────────────────────────────

    def chat(
        self,
        user_message: str,
        conversation_history: Optional[List[Dict[str, str]]] = None,
        student_context: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Generate a chat reply for the given student message.

        Args:
            user_message:          The student's raw message text.
            conversation_history:  Previous turns (last 20 are included).
            student_context:       Student data dict from the frontend.

        Returns:
            Dict with keys: ``success``, ``message``, ``model``,
            and optionally ``error``.  The ``routing`` key carries internal
            metadata (intent, used_fallback) for server-side logging only.
        """
        try:
            # 1. Classify intent
            intent = classify_intent(user_message, student_context or {})

            # 2. Build message list
            messages = self._build_messages(
                user_message, conversation_history, student_context, intent
            )

            # 3. Select model/provider based on intent and data sensitivity
            model, fallback_model, prov, fallback_prov = self._select_routing(
                intent, student_context
            )

            logger.info(
                "[ChatService] routing intent=%s provider=%s model=%s",
                intent.value,
                prov,
                model,
            )

            # 4. Generate reply
            gen: GenerationResult = self.provider.generate_text(
                messages=messages,
                model=model,
                fallback_model=fallback_model,
                provider=prov,
                fallback_provider=fallback_prov,
                temperature=0.7,
                max_tokens=500,
            )

            if gen.used_fallback:
                logger.warning(
                    "[ChatService] used fallback provider=%s model=%s",
                    gen.provider,
                    gen.model,
                )

            # 5. Optional judge evaluation (non-blocking)
            judge_meta: Optional[Dict[str, Any]] = None
            if self.config.enable_chatbot_judge:
                verdict = self.judge.evaluate_chat_response(
                    user_message=user_message,
                    ai_response=gen.content,
                    student_context=student_context,
                    generator_model=gen.model,
                )
                judge_meta = {
                    "passed": verdict.passed,
                    "hallucination_detected": verdict.hallucination_detected,
                    "score": verdict.score,
                    "recommended_action": verdict.recommended_action,
                    "judge_model": verdict.judge_model,
                }
                logger.info(
                    "[ChatService] judge verdict passed=%s score=%.2f action=%s model=%s",
                    verdict.passed,
                    verdict.score,
                    verdict.recommended_action,
                    verdict.judge_model,
                )

            return {
                "success": True,
                "message": gen.content,
                "model": gen.model,
                # routing metadata for server-side logging; not part of public schema
                "routing": {
                    "intent": intent.value,
                    "used_fallback": gen.used_fallback,
                    "provider": gen.provider,
                    "latency_ms": round(gen.latency_ms),
                    "judge": judge_meta,
                },
            }

        except RuntimeError as exc:
            logger.error("[ChatService] generation failed: %s", type(exc).__name__)
            return {
                "success": False,
                "error": str(exc),
                "message": (
                    "I apologize, but I'm experiencing technical difficulties. "
                    "Please try again in a moment."
                ),
            }
        except Exception as exc:
            logger.error("[ChatService] unexpected error: %s", type(exc).__name__)
            return {
                "success": False,
                "error": str(exc),
                "message": (
                    "I apologize, but I'm experiencing technical difficulties. "
                    "Please try again in a moment."
                ),
            }

    def get_quick_suggestions(
        self,
        student_context: Optional[Dict[str, Any]] = None,
    ) -> List[str]:
        """Return up to 5 contextual suggestion chips for the chat UI."""
        suggestions = [
            "What should I study now?",
            "Help me prioritize my tasks",
            "I'm feeling overwhelmed",
            "How can I improve my focus?",
            "Suggest a study schedule",
        ]

        if student_context:
            signals = student_context.get("personalizationSignals")
            urgent_count = 0
            if isinstance(signals, dict):
                urgent_count = int(signals.get("overdueActionableCount") or 0)

            if student_context.get("urgent_tasks") or urgent_count > 0:
                suggestions.insert(0, "What urgent tasks should I do first?")

            if student_context.get("upcoming_deadline"):
                suggestions.insert(1, "Help me prepare for my deadline")

        return suggestions[:5]

    # ── Internal helpers ───────────────────────────────────────────────────────

    def _select_routing(
        self,
        intent: ChatIntent,
        student_context: Optional[Dict[str, Any]],
    ) -> tuple[str, str, str, str]:
        """Return (model, fallback_model, provider, fallback_provider).

        For EDUCATIONAL_QA without sensitive student data, an optional Gemini
        fallback may be used when configured via env vars.
        """
        cfg = self.config
        default = (
            cfg.chat_model,
            cfg.chat_fallback_model,
            cfg.llm_provider,
            cfg.llm_provider,
        )

        if (
            intent == ChatIntent.EDUCATIONAL_QA
            and cfg.educational_fallback_provider
            and cfg.educational_fallback_model
            and not self._has_sensitive_data(student_context)
        ):
            # Primary stays on configured provider; fallback can use Gemini
            return (
                cfg.chat_model,
                cfg.educational_fallback_model,
                cfg.llm_provider,
                cfg.educational_fallback_provider,
            )

        return default

    def _has_sensitive_data(
        self, student_context: Optional[Dict[str, Any]]
    ) -> bool:
        """Return True if the context contains student-specific private data."""
        if not student_context:
            return False
        return bool(
            student_context.get("actionableTasks")
            or student_context.get("tasks")
            or student_context.get("analyticsContext")
            or student_context.get("allSyncedItems")
        )

    def _build_messages(
        self,
        user_message: str,
        conversation_history: Optional[List[Dict[str, str]]],
        student_context: Optional[Dict[str, Any]],
        intent: ChatIntent,
    ) -> List[Dict[str, str]]:
        """Compose the full message list to send to the LLM."""
        messages: List[Dict[str, str]] = [
            {"role": "system", "content": self.system_prompt}
        ]

        if student_context:
            # Only include student data for intents that need it
            if intent in {ChatIntent.USER_DATA_QA, ChatIntent.MIXED_STUDY_ADVICE}:
                ctx_msg = self._build_context_message(student_context)
                if ctx_msg:
                    messages.append({"role": "system", "content": ctx_msg})

        if conversation_history:
            messages.extend(conversation_history[-20:])

        messages.append({"role": "user", "content": user_message})
        return messages

    def _build_context_message(self, context: Dict[str, Any]) -> str:
        """Build a compact, privacy-safe student context block.

        Separates actionable tasks (for scheduling) from analytics rows
        (grade/completed/dashboard-only items) so the LLM cannot confuse them.
        Internal identifiers are intentionally excluded.
        """
        parts: List[str] = []

        if context.get("name"):
            parts.append(f"Student name: {context['name']}")

        # Include all registered courses so the AI knows the full course list
        # even when some courses only have grade items or completed/missed tasks.
        course_list = context.get("courseList") or []
        if course_list:
            parts.append(f"Registered courses this semester ({len(course_list)} total):")
            for c in course_list:
                name = c.get("name", "")
                section = c.get("section", "")
                label = f"{name} — {section}" if section else name
                parts.append(f"  - {label}")

        signals = context.get("personalizationSignals")
        if isinstance(signals, dict):
            parts.append("Personalization signals:")
            for key in sorted(signals.keys()):
                parts.append(f"  - {key}: {signals[key]}")

        raw_actionable = context.get("actionableTasks") or context.get("tasks") or []
        actionable_tasks = _filter_real_tasks(raw_actionable)
        urgent_count = sum(
            1
            for t in actionable_tasks
            if str(t.get("priority", "")).lower() in {"urgent", "high"}
        )
        overdue_count = sum(
            1
            for t in actionable_tasks
            if str(t.get("status", "")).lower() in {"missed", "overdue"}
        )

        parts.append("")
        parts.append(
            "=== SCHEDULABLE TASKS ONLY — only items below may be assigned to any schedule ==="
        )
        parts.append(
            f"Actionable unfinished tasks: {len(actionable_tasks)} "
            f"| Urgent/high: {urgent_count} | Overdue/missed: {overdue_count}"
        )
        # Show up to 60 actionable tasks so 8+ courses with many missed
        # assignments are all visible to the AI.
        for idx, task in enumerate(actionable_tasks[:60], 1):
            parts.append(f"  {idx}. {self._format_context_item(task, include_grade=False)}")
        if len(actionable_tasks) > 60:
            parts.append(
                f"  ... and {len(actionable_tasks) - 60} more actionable tasks"
            )

        analytics = (
            context.get("analyticsContext")
            if isinstance(context.get("analyticsContext"), dict)
            else {}
        )
        grade_items = (analytics or {}).get("gradeItems") or []
        completed_items = (analytics or {}).get("completedItems") or []
        dashboard_items = (analytics or {}).get("dashboardOnlyItems") or []
        all_synced = context.get("allSyncedItems") or []

        parts.append("")
        parts.append(
            "=== GRADE RECORDS & ANALYTICS — these are NOT tasks, NEVER schedule them ==="
        )
        parts.append(
            f"  Synced rows: {len(all_synced)} | Grade records: {len(grade_items)} "
            f"| Completed work: {len(completed_items)} | Dashboard-only: {len(dashboard_items)}"
        )

        if grade_items:
            parts.append(
                "  [GRADE RECORDS — read-only, informational only, NEVER schedulable]:"
            )
            for idx, item in enumerate(grade_items[:12], 1):
                parts.append(f"    {idx}. {self._format_grade_record(item)}")

        if completed_items:
            parts.append("  [COMPLETED WORK — already done, do not re-schedule]:")
            for idx, item in enumerate(completed_items[:8], 1):
                parts.append(f"    {idx}. {self._format_grade_record(item)}")

        if dashboard_items:
            parts.append("  [DASHBOARD ANALYTICS — informational only]:")
            for idx, item in enumerate(dashboard_items[:8], 1):
                parts.append(f"    {idx}. {self._format_grade_record(item)}")

        if "schedule" in context:
            parts.append(f"\nToday's schedule: {context['schedule']}")

        return "Current student context:\n" + "\n".join(parts)

    def _format_context_item(
        self, item: Dict[str, Any], include_grade: bool
    ) -> str:
        """Format a schedulable task for the context block (no internal IDs)."""
        line = item.get("title", "Untitled")
        if item.get("courseName"):
            line += f" | Course: {item['courseName']}"
        if item.get("priority"):
            line += f" | Priority: {item['priority']}"
        if item.get("status"):
            line += f" | Status: {item['status']}"
        if item.get("deadline"):
            line += f" | Deadline: {item['deadline']}"
        if item.get("estimatedMinutes") and not include_grade:
            line += f" | Est: {item['estimatedMinutes']} min"
        if item.get("itemType"):
            line += f" | Type: {item['itemType']}"
        if include_grade:
            assigned = item.get("assignedGrade")
            max_pts = item.get("maxPoints")
            if assigned is not None and max_pts is not None:
                line += f" | Grade: {assigned}/{max_pts}"
            elif assigned is not None:
                line += f" | Grade: {assigned}"
        return line

    def _format_grade_record(self, item: Dict[str, Any]) -> str:
        """Format a grade record or analytics row.

        Intentionally omits the 'status' field so the LLM does not see
        'pending' on a grade record and mistake it for an outstanding task.
        """
        title = item.get("title", "Untitled")
        line = f"[GRADE] {title}"
        if item.get("courseName"):
            line += f" | Course: {item['courseName']}"
        assigned = item.get("assignedGrade")
        max_pts = item.get("maxPoints")
        if assigned is not None and max_pts is not None:
            line += f" | Score: {assigned}/{max_pts}"
        elif assigned is not None:
            line += f" | Score: {assigned}"
        return line

    @staticmethod
    def _get_system_prompt() -> str:
        return (
            "You are an intelligent AI study assistant for UpGrade, a personalized "
            "study planning app. Your role is to help students:\n\n"
            "1. Schedule Management: help reschedule tasks, suggest study times, "
            "and optimize their daily planner.\n"
            "2. Study Guidance: provide study tips, recommend what to study next, "
            "and help prioritize tasks.\n"
            "3. Motivation: encourage students, help manage burnout, and provide "
            "emotional support.\n"
            "4. Academic Advice: answer questions about learning strategies, time "
            "management, and productivity.\n\n"
            "STRICT DATA RULES — follow these exactly:\n\n"
            "RULE 1 — SCHEDULING: You may ONLY schedule or prioritize items that "
            "appear under the '=== SCHEDULABLE TASKS ONLY ===' section. Nothing "
            "else may ever appear in a schedule, to-do list, or action plan.\n\n"
            "RULE 2 — GRADE RECORDS: Any item prefixed with [GRADE] in the context "
            "is a grade record or score summary. These are informational ONLY. "
            "NEVER put a [GRADE] item in a schedule. NEVER tell the student to "
            "'complete', 'work on', or 'get done' a grade record. If asked about "
            "grades or scores, you may report the recorded value, but make clear "
            "it is already graded — not a task to do.\n\n"
            "RULE 3 — COURSES: When asked about registered courses, use the "
            "'Registered courses this semester' list in the context. Report ALL "
            "courses listed there, not just those that have active tasks.\n\n"
            "RULE 4 — MISSED TASKS: Tasks with Status: missed are overdue "
            "assignments the student still needs to submit. Treat them as high "
            "priority in any schedule or advice.\n\n"
            "RULE 5 — NO HALLUCINATION: If specific student data is not present "
            "in the context, clearly say it is not available — never invent data.\n\n"
            "General guidelines:\n"
            "- Be friendly, supportive, and encouraging.\n"
            "- Give practical, actionable advice.\n"
            "- Keep responses concise but helpful.\n"
            "- Respond in the same language as the student (English, Arabic, or "
            "Franco Arabic).\n\n"
            "Remember: You are a study companion, not just a chatbot. "
            "Be personal and understanding."
        )


def test_chat_service() -> None:
    print("Testing AI Chat Service")
    service = AIChatService()
    response = service.chat("Hello! Can you help me study?")
    print(f"Response: {response.get('message', 'ERROR')}")
    print(f"Model: {response.get('model', 'unknown')}")


if __name__ == "__main__":
    test_chat_service()
