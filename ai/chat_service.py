import os
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv
from planner_llm.llm_client import GroqClient
from task_filter import filter_real_tasks as _filter_real_tasks

load_dotenv()


class AIChatService:
    """Service for handling AI chat conversations with students."""

    def __init__(self):
        provider = os.getenv("LLM_PROVIDER", "groq").lower()
        self.client = GroqClient()
        if provider == "groq":
            print("[OK] AI Chat Service initialized with Llama 3.3 (Groq)")
        else:
            print("[OK] AI Chat Service initialized with Llama 3.3 (default Groq)")
        self.system_prompt = self._get_system_prompt()

    def _get_system_prompt(self) -> str:
        return """You are an intelligent AI study assistant for UpGrade, a personalized study planning app. Your role is to help students:

1. Schedule Management: help reschedule tasks, suggest study times, and optimize their daily planner.
2. Study Guidance: provide study tips, recommend what to study next, and help prioritize tasks.
3. Motivation: encourage students, help manage burnout, and provide emotional support.
4. Academic Advice: answer questions about learning strategies, time management, and productivity.

Guidelines:
- Be friendly, supportive, and encouraging.
- Give practical, actionable advice.
- Keep responses concise but helpful.
- If asked about specific tasks, provide relevant recommendations.
- Only schedule or prioritize items listed under "Actionable unfinished tasks".
- Treat grade rows, totals, completed work, materials, and dashboard-only rows as progress or personalization context only.
- Never describe grade rows, totals, completed work, or dashboard-only rows as tasks the student still needs to complete.

Remember: You are a study companion, not just a chatbot. Be personal and understanding."""

    def chat(
        self,
        user_message: str,
        conversation_history: Optional[List[Dict[str, str]]] = None,
        student_context: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        try:
            messages = [{"role": "system", "content": self.system_prompt}]

            if student_context:
                context_msg = self._build_context_message(student_context)
                if context_msg:
                    messages.append({"role": "system", "content": context_msg})

            if conversation_history:
                messages.extend(conversation_history[-20:])

            messages.append({"role": "user", "content": user_message})

            print(f"Processing chat message: {user_message[:60]}...")
            response = self.client.chat_completion(
                messages=messages,
                temperature=0.7,
                max_tokens=500,
            )

            if "choices" in response and len(response["choices"]) > 0:
                return {
                    "success": True,
                    "message": response["choices"][0]["message"]["content"],
                    "usage": response.get("usage", {}),
                    "model": response.get("model", "llama-3.3-70b-versatile"),
                }

            return {
                "success": False,
                "error": "Failed to get response from AI",
                "message": "I'm having trouble responding right now. Please try again.",
            }
        except Exception as exc:
            print(f"Error in chat service: {str(exc)}")
            return {
                "success": False,
                "error": str(exc),
                "message": "I apologize, but I'm experiencing technical difficulties. Please try again in a moment.",
            }

    def _build_context_message(self, context: Dict[str, Any]) -> str:
        parts: List[str] = []

        if context.get("name"):
            parts.append(f"Student name: {context['name']}")

        signals = context.get("personalizationSignals")
        if isinstance(signals, dict):
            parts.append("Personalization signals:")
            for key in sorted(signals.keys()):
                parts.append(f"  - {key}: {signals[key]}")

        raw_actionable = context.get("actionableTasks") or context.get("tasks") or []
        actionable_tasks = _filter_real_tasks(raw_actionable)
        urgent_count = sum(
            1
            for task in actionable_tasks
            if str(task.get("priority", "")).lower() in {"urgent", "high"}
        )
        overdue_count = sum(
            1
            for task in actionable_tasks
            if str(task.get("status", "")).lower() in {"missed", "overdue"}
        )

        parts.append("")
        parts.append(
            "Actionable unfinished tasks (only these may be scheduled): "
            f"{len(actionable_tasks)} | Urgent/high: {urgent_count} "
            f"| Overdue/missed: {overdue_count}"
        )
        for index, task in enumerate(actionable_tasks[:20], 1):
            parts.append(
                f"  {index}. {self._format_context_item(task, include_grade=False)}"
            )

        analytics = (
            context.get("analyticsContext")
            if isinstance(context.get("analyticsContext"), dict)
            else {}
        )
        grade_items = analytics.get("gradeItems") or []
        completed_items = analytics.get("completedItems") or []
        dashboard_items = analytics.get("dashboardOnlyItems") or []
        all_synced_items = context.get("allSyncedItems") or []

        parts.append("")
        parts.append(
            "Analytics/progress context only. Do not schedule these rows as tasks."
        )
        parts.append(
            f"  - Synced rows: {len(all_synced_items)} | Grade rows: {len(grade_items)} "
            f"| Completed rows: {len(completed_items)} | Dashboard-only rows: {len(dashboard_items)}"
        )

        if grade_items:
            parts.append("  Grade/progress rows:")
            for index, item in enumerate(grade_items[:12], 1):
                parts.append(
                    f"    {index}. {self._format_context_item(item, include_grade=True)}"
                )

        if completed_items:
            parts.append("  Recently completed/returned rows:")
            for index, item in enumerate(completed_items[:8], 1):
                parts.append(
                    f"    {index}. {self._format_context_item(item, include_grade=True)}"
                )

        if dashboard_items:
            parts.append("  Dashboard-only rows:")
            for index, item in enumerate(dashboard_items[:8], 1):
                parts.append(
                    f"    {index}. {self._format_context_item(item, include_grade=True)}"
                )

        if "schedule" in context:
            parts.append(f"\nToday's schedule: {context['schedule']}")

        return "Current student context:\n" + "\n".join(parts)

    def _format_context_item(self, item: Dict[str, Any], include_grade: bool) -> str:
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
            max_points = item.get("maxPoints")
            if assigned is not None and max_points is not None:
                line += f" | Grade: {assigned}/{max_points}"
            elif assigned is not None:
                line += f" | Grade: {assigned}"
        return line

    def get_quick_suggestions(
        self,
        student_context: Optional[Dict[str, Any]] = None,
    ) -> List[str]:
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


def test_chat_service():
    print("Testing AI Chat Service with Llama 3.3")
    service = AIChatService()
    response = service.chat("Hello! Can you help me study?")
    print(f"Response: {response.get('message', 'ERROR')}\n")
    print(f"Model: {response.get('model', 'unknown')}\n")


if __name__ == "__main__":
    test_chat_service()
