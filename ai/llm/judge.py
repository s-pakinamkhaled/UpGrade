"""
LLM-as-a-Judge for UpGrade AI responses.

The judge evaluates generated content for:
- Hallucination: did the model invent tasks, courses, grades, or deadlines
  that were not present in the input context?
- Privacy safety: are internal identifiers or excess student data exposed?
- Accuracy: do plan items match the provided task list?
- Helpfulness: is the response relevant?

The judge is entirely opt-in via environment flags:
    ENABLE_LLM_JUDGE=true
    ENABLE_STUDY_PLAN_JUDGE=true
    ENABLE_CHATBOT_JUDGE=true

When disabled, all evaluate_* calls immediately return a pass-through
``JudgeResult`` with ``passed=True`` so no code paths need to branch on
whether the judge is active.

Logging
-------
Judge results (model, passed, hallucination, score, action) are logged at
INFO/WARNING level.  Message content and student data are NEVER logged.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from .config import LLMConfig
from .provider import LLMProvider

logger = logging.getLogger(__name__)

_JUDGE_SYSTEM_PROMPT = """\
You are a strict AI output evaluator for an academic study assistant app.
Evaluate the AI-generated content for:
1. Hallucination — did the AI mention tasks, courses, grades, or deadlines
   that are NOT present in the provided context?
2. Privacy — did the AI expose internal system IDs or unnecessary data?
3. Accuracy — do plan items/responses accurately reflect the provided context?
4. Helpfulness — is the response relevant and useful to the student?

You MUST respond with valid JSON only — no markdown fences, no extra text.
Required JSON schema:
{
  "passed": true|false,
  "hallucination_detected": true|false,
  "score": 0.0..1.0,
  "issues": ["specific issue 1", "specific issue 2"],
  "recommended_action": "accept|warn|reject|retry",
  "reasoning": "brief explanation"
}
"""

_HALLUCINATION_CHECK_GUIDE = """\
Hallucination check rules:
- A task/course is hallucinated if it appears in the output but NOT in the
  provided input context.
- A grade/score is hallucinated if it was not given in the input.
- A deadline is hallucinated if it does not match the input context.
- Student names that differ from the provided name are hallucinated.
"""


@dataclass
class JudgeResult:
    """Structured evaluation output from the LLM judge."""

    passed: bool
    hallucination_detected: bool
    score: float  # 0.0 = fail, 1.0 = perfect
    issues: List[str]
    recommended_action: str  # "accept" | "warn" | "reject" | "retry"
    reasoning: str
    judge_model: str
    judge_provider: str


class LLMJudge:
    """Evaluates AI-generated content using a configurable judge model.

    Args:
        config:   Loaded ``LLMConfig`` instance (reads judge flags and models).
        provider: A shared ``LLMProvider`` instance for making judge calls.
    """

    def __init__(self, config: LLMConfig, provider: LLMProvider) -> None:
        self.config = config
        self.provider = provider

    # ── Public evaluation methods ──────────────────────────────────────────────

    def evaluate_chat_response(
        self,
        user_message: str,
        ai_response: str,
        student_context: Optional[Dict[str, Any]] = None,
        generator_model: str = "",
    ) -> JudgeResult:
        """Evaluate a chatbot response for hallucination and quality.

        Args:
            user_message:    The user's original message (truncated to 500 chars
                             when building the judge prompt).
            ai_response:     The AI-generated reply.
            student_context: Student context that was provided to the generator.
            generator_model: Model that produced the response; the judge will
                             prefer a *different* model when possible.

        Returns:
            ``JudgeResult`` with structured evaluation.
        """
        if not self.config.enable_chatbot_judge:
            return self._passthrough("chatbot judge disabled")

        judge_model = self._select_judge_model(generator_model)
        context_summary = self._compact_context_summary(student_context)

        prompt = (
            f"Evaluate this AI study assistant response:\n\n"
            f"User message (first 500 chars): {user_message[:500]}\n\n"
            f"Student context summary (no IDs):\n{context_summary}\n\n"
            f"AI response (first 2000 chars):\n{ai_response[:2000]}\n\n"
            f"{_HALLUCINATION_CHECK_GUIDE}\n"
            f"Rate the response and return JSON."
        )

        return self._run_judge(prompt, judge_model, operation="chatbot")

    def evaluate_study_plan(
        self,
        plan_items: List[Dict[str, Any]],
        input_tasks: List[Dict[str, Any]],
        summary: str,
        generator_model: str = "",
    ) -> JudgeResult:
        """Evaluate a generated study plan.

        Checks that every plan item corresponds to an actual input task and
        that no grades, deadlines, or courses were invented.

        Args:
            plan_items:      Items in the generated plan.
            input_tasks:     Tasks that were passed to the planner.
            summary:         Generated plan summary text.
            generator_model: Model that generated the plan.

        Returns:
            ``JudgeResult`` with structured evaluation.
        """
        if not self.config.enable_study_plan_judge:
            return self._passthrough("study plan judge disabled")

        judge_model = self._select_judge_model(generator_model)

        task_lines = "\n".join(
            f"  - {t.get('title', 'N/A')} | "
            f"course: {t.get('courseName', 'N/A')} | "
            f"deadline: {t.get('deadline', 'none')}"
            for t in input_tasks[:20]
        )
        plan_lines = "\n".join(
            f"  - {p.get('taskTitle', 'N/A')} | "
            f"date: {p.get('suggestedDate', 'N/A')} | "
            f"priority: {p.get('priority', 'N/A')}"
            for p in plan_items[:20]
        )

        prompt = (
            f"Evaluate this AI-generated study plan:\n\n"
            f"Input tasks provided ({len(input_tasks)} total, showing first 20):\n"
            f"{task_lines}\n\n"
            f"Generated plan items ({len(plan_items)} total, showing first 20):\n"
            f"{plan_lines}\n\n"
            f"Generated summary (first 500 chars): {summary[:500]}\n\n"
            f"{_HALLUCINATION_CHECK_GUIDE}\n"
            f"Verify that all plan tasks exist in the input list, no grades were "
            f"invented, and deadlines match. Return JSON evaluation."
        )

        return self._run_judge(prompt, judge_model, operation="study_plan")

    # ── Internal helpers ───────────────────────────────────────────────────────

    def _run_judge(
        self,
        prompt: str,
        judge_model: str,
        operation: str,
    ) -> JudgeResult:
        messages = [
            {"role": "system", "content": _JUDGE_SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ]

        try:
            parsed, gen_result = self.provider.generate_json(
                messages=messages,
                model=judge_model,
                fallback_model=self.config.judge_fallback_model,
                temperature=0.1,
                max_tokens=500,
            )

            result = JudgeResult(
                passed=bool(parsed.get("passed", True)),
                hallucination_detected=bool(parsed.get("hallucination_detected", False)),
                score=float(parsed.get("score", 0.8)),
                issues=list(parsed.get("issues", [])),
                recommended_action=str(parsed.get("recommended_action", "accept")),
                reasoning=str(parsed.get("reasoning", "")),
                judge_model=gen_result.model,
                judge_provider=gen_result.provider,
            )

            log_level = logging.WARNING if not result.passed else logging.INFO
            logger.log(
                log_level,
                "[Judge] operation=%s passed=%s hallucination=%s score=%.2f "
                "action=%s model=%s",
                operation,
                result.passed,
                result.hallucination_detected,
                result.score,
                result.recommended_action,
                gen_result.model,
            )
            return result

        except Exception as exc:
            logger.warning(
                "[Judge] evaluation failed for operation=%s error=%s",
                operation,
                type(exc).__name__,
            )
            return self._passthrough(f"judge error: {type(exc).__name__}")

    def _select_judge_model(self, generator_model: str) -> str:
        """Choose a judge model, preferring one different from the generator."""
        primary = self.config.judge_model
        fallback = self.config.judge_fallback_model

        # Use the fallback judge model when the primary would be the same as
        # the generator — a different model provides more independent feedback.
        if primary and primary != generator_model:
            return primary
        if fallback and fallback != generator_model:
            return fallback
        return primary or fallback or generator_model

    def _compact_context_summary(
        self,
        context: Optional[Dict[str, Any]],
    ) -> str:
        """Build a minimal context summary for the judge prompt.

        Deliberately omits internal IDs and raw task lists to keep the judge
        prompt small and privacy-safe.
        """
        if not context:
            return "No student context provided."

        lines: List[str] = []

        if context.get("name"):
            lines.append(f"Student name: {context['name']}")

        tasks = context.get("actionableTasks") or context.get("tasks") or []
        if tasks:
            lines.append(f"Actionable tasks count: {len(tasks)}")
            for t in tasks[:10]:
                title = t.get("title", "N/A") if isinstance(t, dict) else "N/A"
                course = t.get("courseName", "N/A") if isinstance(t, dict) else "N/A"
                lines.append(f"  - {title} | course: {course}")

        return "\n".join(lines) if lines else "Minimal context."

    def _passthrough(self, reason: str = "") -> JudgeResult:
        """Return a neutral passing result when the judge is skipped."""
        return JudgeResult(
            passed=True,
            hallucination_detected=False,
            score=1.0,
            issues=[],
            recommended_action="accept",
            reasoning=reason,
            judge_model="",
            judge_provider="",
        )
