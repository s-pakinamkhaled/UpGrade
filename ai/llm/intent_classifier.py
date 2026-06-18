"""
Intent classification for the UpGrade chatbot.

Classifies each user message into one of three intents so the chat router
can decide which model/provider to use and whether student data is required.

Intents
-------
USER_DATA_QA
    The question is about the student's own tasks, schedule, grades, or
    progress.  Student context is required; never route to an external
    educational fallback.

EDUCATIONAL_QA
    A general academic question (study tips, concept explanations, etc.)
    that does not require student-specific data.  May be routed to an
    educational fallback provider (e.g. Gemini) when no sensitive student
    data is involved.

MIXED_STUDY_ADVICE
    A blend of personal advice and general guidance — the student is asking
    for help with their own work but the answer also draws on general
    academic knowledge.  Treat as USER_DATA_QA for routing purposes.
"""

from __future__ import annotations

from enum import Enum
from typing import Any, Dict


class ChatIntent(str, Enum):
    USER_DATA_QA = "USER_DATA_QA"
    EDUCATIONAL_QA = "EDUCATIONAL_QA"
    MIXED_STUDY_ADVICE = "MIXED_STUDY_ADVICE"


# Keywords that signal the user is asking about *their own* data
_USER_DATA_KEYWORDS: frozenset[str] = frozenset(
    {
        "my tasks",
        "my courses",
        "my schedule",
        "my grade",
        "my grades",
        "my assignment",
        "my assignments",
        "my tasks",
        "my tasks for today",
        "my tasks for tomorrow",
        "my tasks for the week",
        "rate my work",
        "rate my assignments",
        "rate my tasks",
        "rate my projects",
        "rate my exams",
        "rate my quizzes",
        "rate my midterms",
        "rate my finals",
        "rate my term work",
        "rate my performence"
        "my deadline",
        "rate my grades"
        "my deadlines",
        "my upcoming",
        "my progress",
        "my study plan",
        "my planner",
        "when is my",
        "what do i have",
        "remind me",
        "am i on track",
        "how am i doing",
        # Arabic
        "واجباتي",
        "جدولي",
        "درجاتي",
        "مهامي",
        "تقدمي",
        # Franco Arabic
        "mawad bta3ty",
        "tasks bta3ty",
    }
)

# Keywords that signal a general academic / educational question
_EDUCATIONAL_KEYWORDS: frozenset[str] = frozenset(
    {
        "how to study",
        "study tips",
        "study strategy",
        "what is",
        "what are",
        "explain",
        "difference between",
        "learning strategy",
        "time management",
        "focus tips",
        "motivation",
        "procrastination",
        "memory techniques",
        "pomodoro",
        "spaced repetition",
        "active recall",
        "how does",
        "why is",
        "best way to learn",
        "help me understand",
        "can you explain",
        "tell me about",
        # Arabic
        "تقنية",
        "طريقة",
        "كيف أذاكر",
        "نصائح للمذاكرة",
        "نصائح",
        # Franco Arabic
        "ezay azaker",
        "nasayeh",
    }
)

# Pronouns that suggest the question is personal
_PERSONAL_PRONOUNS: frozenset[str] = frozenset(
    {"my", "i", "me", "i'm", "im", "ana", "انا", "لي", "بتاعتي"}
)


def classify_intent(
    message: str,
    student_context: Dict[str, Any],
) -> ChatIntent:
    """Classify a chat message into one of three intents.

    Classification is purely keyword / heuristic-based — no LLM call is
    made — to keep latency low and avoid circular model dependencies.

    Args:
        message:         Raw user message text.
        student_context: The student context dict sent with the request.
                         Used to determine whether personal data is present.

    Returns:
        A ``ChatIntent`` value.
    """
    msg_lower = message.lower()

    has_context = bool(
        student_context
        and (
            student_context.get("actionableTasks")
            or student_context.get("tasks")
            or student_context.get("name")
        )
    )

    user_data_match = any(kw in msg_lower for kw in _USER_DATA_KEYWORDS)
    educational_match = any(kw in msg_lower for kw in _EDUCATIONAL_KEYWORDS)

    words = set(msg_lower.split())
    personal_pronoun = bool(words & _PERSONAL_PRONOUNS)

    # Explicit reference to own data → always USER_DATA_QA or MIXED
    if user_data_match:
        return ChatIntent.MIXED_STUDY_ADVICE if educational_match else ChatIntent.USER_DATA_QA

    # Personal pronoun + student data present → treat as user-data oriented
    if personal_pronoun and has_context:
        return ChatIntent.MIXED_STUDY_ADVICE if educational_match else ChatIntent.USER_DATA_QA

    # General question, no personal pronoun → EDUCATIONAL
    if educational_match:
        return ChatIntent.EDUCATIONAL_QA

    # Default: if student context is available lean toward personal advice,
    # otherwise treat as educational
    return ChatIntent.MIXED_STUDY_ADVICE if has_context else ChatIntent.EDUCATIONAL_QA
