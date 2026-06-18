# LLM Routing Architecture — UpGrade

This document covers the configurable LLM routing system introduced in the
UpGrade backend.  It explains every new environment variable, how providers
are set up, fallback behaviour, the judge, and how the chatbot classifies
requests internally.

---

## Table of Contents

1. [New Environment Variables](#new-environment-variables)
2. [Provider Setup](#provider-setup)
3. [Routing Flow](#routing-flow)
4. [Fallback Flow](#fallback-flow)
5. [Internal Chatbot Intent Routing](#internal-chatbot-intent-routing)
6. [LLM-as-a-Judge](#llm-as-a-judge)
7. [Privacy Guarantees](#privacy-guarantees)
8. [Logging](#logging)
9. [Testing Instructions](#testing-instructions)

---

## New Environment Variables

Add these to both `backend/.env` **and** `ai/.env` (they are loaded by both
the route layer and the ai package).

### Provider

| Variable | Default | Description |
|---|---|---|
| `LLM_PROVIDER` | `groq` | Primary provider. `groq` or `gemini`. |

### Groq

| Variable | Default | Description |
|---|---|---|
| `GROQ_API_KEY` | *(required)* | Groq API key. |
| `GROQ_API_BASE` | `https://api.groq.com/openai/v1` | Groq base URL. |

### Gemini (optional)

| Variable | Default | Description |
|---|---|---|
| `GEMINI_API_KEY` | — | Google Gemini API key. Required only when Gemini is used. |

### Plan Models

| Variable | Default | Description |
|---|---|---|
| `PLAN_MODEL` | `llama-3.3-70b-versatile` | Primary model for study plan generation. |
| `PLAN_FALLBACK_MODEL` | `llama-3.1-8b-instant` | Fallback model if primary fails. |

### Chat Models

| Variable | Default | Description |
|---|---|---|
| `CHAT_MODEL` | `llama-3.3-70b-versatile` | Primary model for chatbot responses. |
| `CHAT_FALLBACK_MODEL` | `llama-3.1-8b-instant` | Fallback model if primary fails. |

### Judge Models

| Variable | Default | Description |
|---|---|---|
| `JUDGE_MODEL` | `llama-3.3-70b-versatile` | Primary model for LLM-as-a-Judge. Automatically uses a different model than the generator when possible. |
| `JUDGE_FALLBACK_MODEL` | `llama-3.1-8b-instant` | Fallback judge model. |

### Educational Fallback (optional)

| Variable | Default | Description |
|---|---|---|
| `EDUCATIONAL_FALLBACK_PROVIDER` | — | Provider for educational-only fallback (e.g. `gemini`). Activated only when intent is `EDUCATIONAL_QA` **and** no sensitive student data is present. |
| `EDUCATIONAL_FALLBACK_MODEL` | — | Model to use on the educational fallback provider. |

### Judge Feature Flags

| Variable | Default | Description |
|---|---|---|
| `ENABLE_LLM_JUDGE` | `false` | Master switch for the judge system. |
| `ENABLE_STUDY_PLAN_JUDGE` | `false` | Enable judge for study plan responses. |
| `ENABLE_CHATBOT_JUDGE` | `false` | Enable judge for chatbot responses. |

---

## Provider Setup

### Groq (default)

Groq exposes an OpenAI-compatible REST API. No extra Python packages are
needed — the system uses `requests` directly.

```env
LLM_PROVIDER=groq
GROQ_API_KEY=gsk_...
GROQ_API_BASE=https://api.groq.com/openai/v1
PLAN_MODEL=llama-3.3-70b-versatile
PLAN_FALLBACK_MODEL=llama-3.1-8b-instant
```

### Gemini

To use Gemini as the primary provider:

```env
LLM_PROVIDER=gemini
GEMINI_API_KEY=AIza...
PLAN_MODEL=gemini-1.5-pro
PLAN_FALLBACK_MODEL=gemini-1.5-flash
CHAT_MODEL=gemini-1.5-pro
CHAT_FALLBACK_MODEL=gemini-1.5-flash
```

### Mixed (Groq primary + Gemini educational fallback)

```env
LLM_PROVIDER=groq
GROQ_API_KEY=gsk_...
GEMINI_API_KEY=AIza...
EDUCATIONAL_FALLBACK_PROVIDER=gemini
EDUCATIONAL_FALLBACK_MODEL=gemini-1.5-flash
```

In this configuration, general educational questions that contain no student
data are answered via Gemini when the Groq call fails, while all
student-specific data queries remain on Groq.

---

## Routing Flow

```
Flutter frontend
  │
  │  POST /api/chat/message
  ▼
FastAPI chat.py
  │
  ├─ validate_chat_message() ── security guard
  │
  ├─ AIChatService.chat()
  │     │
  │     ├─ classify_intent(message, student_context)
  │     │       → USER_DATA_QA | EDUCATIONAL_QA | MIXED_STUDY_ADVICE
  │     │
  │     ├─ _select_routing(intent, context)
  │     │       → (model, fallback_model, provider, fallback_provider)
  │     │
  │     ├─ _build_messages()
  │     │       → Only includes student context for USER_DATA_QA / MIXED
  │     │
  │     └─ LLMProvider.generate_text(...)
  │           → returns GenerationResult
  │
  ├─ LLMJudge.evaluate_chat_response()  [if ENABLE_CHATBOT_JUDGE=true]
  │       → logs result, non-blocking
  │
  └─ ChatResponse  (unchanged schema — Flutter sees no difference)


  POST /api/plan/generate
  │
  ├─ _filter_real_tasks()  ── removes grades, completed, materials
  ├─ sort by priority / deadline
  ├─ LLMProvider.generate_json(PLAN_MODEL, PLAN_FALLBACK_MODEL)
  │     → retry once → fallback model
  ├─ Validate JSON items against real task list (hallucination guard)
  ├─ _fallback_plan_item() for any LLM-omitted tasks
  ├─ LLMJudge.evaluate_study_plan()  [if ENABLE_STUDY_PLAN_JUDGE=true]
  └─ PlanResponse  (unchanged schema)
```

---

## Fallback Flow

```
Primary model call (attempt 1)
  │
  ├── success → return GenerationResult(used_fallback=False)
  │
  └── failure
        │
        ├── wait 1 s
        │
        ├── Primary model call (attempt 2)
        │     │
        │     ├── success → return GenerationResult(used_fallback=False)
        │     │
        │     └── failure
        │           │
        │           └── Fallback model call (single attempt)
        │                 │
        │                 ├── success → return GenerationResult(used_fallback=True)
        │                 │
        │                 └── failure → raise RuntimeError
        │                       │
        │                       └── Route returns 502 (planner)
        │                           or {"success": False, "message": safe_error}
        │                           (chatbot)
```

Fallback is logged at `WARNING` level with `used_fallback=True` and the
fallback model name.

---

## Internal Chatbot Intent Routing

The single `POST /api/chat/message` endpoint is unchanged from the frontend's
perspective.  Internally, every request is classified into one of three intents
**before** any LLM call is made (pure keyword matching, no extra latency):

| Intent | Trigger | Context included? | Educational fallback? |
|---|---|---|---|
| `USER_DATA_QA` | "my tasks", "my grades", Arabic equivalents | Yes | Never |
| `EDUCATIONAL_QA` | "how to study", "explain X", "study tips" | No (safe) | Yes, if configured and no sensitive data |
| `MIXED_STUDY_ADVICE` | Personal pronouns + context, or mixed signals | Yes | Never |

### Privacy rule for EDUCATIONAL fallback

The educational fallback (e.g. Gemini) is only activated when **all** of the
following are true:

1. Intent is `EDUCATIONAL_QA`
2. `EDUCATIONAL_FALLBACK_PROVIDER` and `EDUCATIONAL_FALLBACK_MODEL` are set
3. The request contains **no** sensitive student data (no `actionableTasks`,
   `tasks`, `analyticsContext`, or `allSyncedItems`)

This guarantees that grades, task titles, course names, and schedules are
never sent to a secondary external provider.

---

## LLM-as-a-Judge

The judge is an independent LLM call that evaluates generated content for
hallucination, privacy, accuracy, and helpfulness.  It runs **after** the
main generation and is **non-blocking** — a failed judge never prevents a
response from reaching the student.

### Enable

```env
ENABLE_LLM_JUDGE=true
ENABLE_STUDY_PLAN_JUDGE=true   # judge study plan generation
ENABLE_CHATBOT_JUDGE=true      # judge chatbot responses
JUDGE_MODEL=llama-3.3-70b-versatile
JUDGE_FALLBACK_MODEL=llama-3.1-8b-instant
```

### Judge output schema (logged, not returned to frontend)

```json
{
  "passed": true,
  "hallucination_detected": false,
  "score": 0.95,
  "issues": [],
  "recommended_action": "accept",
  "reasoning": "All tasks match the input context."
}
```

`recommended_action` values:

| Value | Meaning |
|---|---|
| `accept` | Response is good; proceed normally |
| `warn` | Minor issues; response delivered but logged as warning |
| `reject` | Significant issues detected; logged as warning |
| `retry` | Judge recommends regenerating; logged, not auto-retried |

### Model selection

The judge automatically selects a **different** model than the generator when
possible.  If `JUDGE_MODEL` equals the generator model, it falls back to
`JUDGE_FALLBACK_MODEL`.

### What is evaluated

**Chatbot responses:**
- Were any tasks/courses mentioned that are not in the student context?
- Were grades or deadlines invented?
- Is the response helpful and relevant?

**Study plans:**
- Do all plan items correspond to real input tasks?
- Were any course names, grades, or deadlines invented?
- Are priority levels consistent with input deadlines?

---

## Privacy Guarantees

| Guarantee | How it is enforced |
|---|---|
| No internal IDs sent to LLMs | `_build_context_message()` and judge's `_compact_context_summary()` both exclude task IDs |
| Student data stays on primary provider | Intent classifier blocks educational fallback whenever student context is present |
| Task filtering before LLM call | `filter_real_tasks()` removes grades, completed items, materials before building prompts |
| No prompt/data logging | Only provider name, model, latency, and intent are logged |

---

## Logging

All routing events are logged at `INFO` / `WARNING` level (never `DEBUG` for
sensitive data).

Sample log lines:

```
INFO  [ChatService] routing intent=MIXED_STUDY_ADVICE provider=groq model=llama-3.3-70b-versatile
INFO  [LLM] provider=groq model=llama-3.3-70b-versatile attempt=1 latency_ms=842 used_fallback=False
WARN  [LLM] primary exhausted; falling back to provider=groq model=llama-3.1-8b-instant
INFO  [LLM] provider=groq model=llama-3.1-8b-instant latency_ms=1203 used_fallback=True
INFO  [Judge] operation=chatbot passed=True hallucination=False score=0.92 action=accept model=llama-3.3-70b-versatile
INFO  [Planner] generated provider=groq model=llama-3.3-70b-versatile used_fallback=False latency_ms=2541
```

---

## Testing Instructions

### 1. Install dependencies

```bash
cd backend
pip install -r requirements.txt
pip install pytest
```

### 2. Run all new LLM tests (no API key needed — all mocked)

```bash
cd backend
python -m pytest tests/test_llm_config.py tests/test_llm_routing.py tests/test_llm_judge.py tests/test_intent_routing.py -v
```

### 3. Run the updated chat service tests

```bash
python -m pytest tests/test_ai_chat_service.py -v
```

### 4. Run the full test suite

```bash
python -m pytest tests/ -v
```

### 5. Test the running server

```bash
# Start the backend
cd backend
uvicorn app.main:app --reload --port 8001

# Health check
curl http://localhost:8001/api/chat/health
# Expected: {"status":"ok","service":"llama-3.3-70b-versatile","provider":"groq","fallback":"llama-3.1-8b-instant"}

curl http://localhost:8001/api/plan/health
# Expected: {"status":"ok","service":"llama-3.3-70b-versatile","provider":"groq","fallback":"llama-3.1-8b-instant"}

# Chat message (unchanged request/response schema)
curl -X POST http://localhost:8001/api/chat/message \
  -H "Content-Type: application/json" \
  -d '{"message": "What study tips do you have?"}'

# Study plan generation (unchanged schema)
curl -X POST http://localhost:8001/api/plan/generate \
  -H "Content-Type: application/json" \
  -d '{"studentName":"Test","tasks":[{"id":"1","title":"Math HW","priority":"high","estimatedMinutes":60,"hasRealDeadline":true,"deadline":"2025-01-25T00:00:00"}]}'
```

### 6. Test fallback behaviour

Set an invalid primary model to trigger fallback:

```env
CHAT_MODEL=invalid-model-name
CHAT_FALLBACK_MODEL=llama-3.1-8b-instant
```

The system will log a warning and fall back automatically. Response schema is
unchanged.

### 7. Enable and test the judge

```env
ENABLE_STUDY_PLAN_JUDGE=true
ENABLE_CHATBOT_JUDGE=true
JUDGE_MODEL=llama-3.3-70b-versatile
JUDGE_FALLBACK_MODEL=llama-3.1-8b-instant
```

Judge results appear in server logs only — they never change the API response.
