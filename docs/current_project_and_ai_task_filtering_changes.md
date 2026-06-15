# UpGrade Current Project Documentation

## Project Overview

UpGrade is an AI-powered personalized study assistant. The project connects to Google Classroom, syncs student academic data, stores it locally in the Flutter app, and uses backend AI services to generate study plans, chatbot responses, dashboard insights, warnings, and study-group support.

The current stack is:

- `frontend/`: Flutter app for web/desktop/mobile UI.
- `backend/`: FastAPI backend for API routes, task tracking, planner, chat, notifications, profile, and Classroom proxy/sync support.
- `ai/`: AI helper services, Groq client integration, chat service, and task filtering guardrails.
- `docs/`: Project documentation and run instructions.

## Main Data Flow

The important academic-data flow is:

```text
Google Classroom raw data
  -> frontend Classroom models
  -> ClassroomMapperService
  -> ClassroomItemClassifierService
  -> local storage / provider state
  -> Dashboard uses all useful synced context
  -> Study Plan uses only actionable unfinished tasks
  -> Chatbot receives separated task + analytics context
  -> Backend validates/filter tasks again before Groq
```

## Core Problem Solved

Google Classroom returns different kinds of `courseWork` rows. Not all rows are real tasks. Some are:

- real unfinished assignments
- completed/submitted work
- grade rows
- grade buckets/totals
- rubrics
- quiz/assessment rows
- dashboard-only rows
- material/context rows

Before the fix, the Study Plan and Chatbot could treat rows like `Midterm Grades`, `Total Course Work`, `Public Speaking Assessment 2%`, `Debate Quiz`, or rubric/marking rows as real tasks. This caused inaccurate AI plans.

## Classification Layer

The main frontend classifier is:

- `frontend/lib/services/classroom_item_classifier_service.dart`

It classifies each synced row into:

- `actionable_task`
- `grade_item`
- `grade_bucket`
- `completed_work`
- `material`
- `dashboard_only`
- `unknown`

It also sets metadata:

- `source`
- `itemType`
- `isActionableForAI`
- `isGradeRelated`
- `isDashboardOnly`
- `classificationConfidence`
- `classificationReason`
- `classroomWorkType`
- `classroomSubmissionState`
- `classroomLate`
- `hasRealDeadline`

The classifier uses metadata first, then title/content rules. This is important because metadata is more reliable than prompt instructions.

## Mapper Changes

Updated file:

- `frontend/lib/services/classroom_mapper_service.dart`

The mapper now preserves more Classroom facts:

- whether Classroom provided a real due date
- submission state such as `CREATED`, `TURNED_IN`, `RETURNED`
- whether Classroom marked the submission late
- work type such as `ASSIGNMENT`, `MATERIAL`, `SHORT_ANSWER_QUESTION`

Priority logic was also corrected:

- missed or overdue real-deadline work -> `urgent`
- due within 24 hours -> `urgent`
- due within 72 hours -> `high`
- due within 7 days -> at least `medium`
- no real deadline -> `low`
- completed/submitted work -> `low`

This fixes the issue where `Assignment 7` with no due date appeared as `medium`.

## Task Model Changes

Updated file:

- `frontend/lib/models/task.dart`

The `Task` model now includes classification and Classroom metadata. Old cached data is also handled defensively: if an old synced task has a synthetic deadline around `now + 7 days`, it is treated as not having a real deadline.

Deadline metadata now distinguishes:

- `hasRealDeadline=false`: Classroom did not provide a due date, so the displayed deadline is `No deadline`.
- `deadlineSource=classroom`: due date came from Google Classroom.
- `deadlineSource=user`: the student manually set a planning deadline.
- `deadlineSource=synthetic`: internal placeholder only; it must not be shown or scheduled as a real deadline.

When a student sets a deadline for a no-due-date Classroom task, the app persists it as `deadlineSource=user`, reclassifies the task, recalculates priority, and preserves the custom date on future Classroom syncs unless Classroom later provides a real due date.

## Study Plan Changes

Updated files:

- `frontend/lib/screens/study_plan_screen.dart`
- `frontend/lib/models/study_plan.dart`
- `frontend/lib/services/api_service.dart`
- `backend/app/api/routes/planner.py`

Study Plan now uses only:

```dart
provider.upcomingActionableTasks
```

This excludes grade rows, rubric rows, completed work, materials, and dashboard-only rows.

The Study Plan UI now shows a clearer planning table with:

- task name
- priority
- deadline
- deadline action for unknown dates
- status
- finish window
- course

Rows with `No deadline` show a `Set date` action. After the student selects a date and time, the plan regenerates using the updated deadline.

The backend planner also validates the tasks again before calling Groq. If Groq omits a validated real task, the backend appends a deterministic catch-up plan item so missed assignments like Assignment 8 and Assignment 9 do not disappear from the final plan.

## Backend AI Safety Filter

Updated file:

- `ai/task_filter.py`

This is the backend guardrail before AI calls. It rejects fake or non-schedulable rows even if an old frontend client sends bad metadata.

Examples filtered out:

- `Lecture Quizzes [5]`
- `Midterm Grades`
- `Total Course Work`
- `Public Speaking Assessment 2%`
- `Public Speaking Assessment Instructions and Rubric`
- `Debate Quiz`
- `Outline Quiz`
- `Sample Essay Marking`
- `Persuasive Essay Outline (6%)`
- `Lab03- Practical`

Examples preserved:

- `Assignment 7 ... (not graded)`
- `Assignment 8`
- `Assignment 9`
- project reports
- homework
- lab delivery
- real pending/missed/in-progress deliverables

## Chatbot Changes

Updated files:

- `frontend/lib/screens/ai_chatbot_screen.dart`
- `ai/chat_service.py`

The chatbot now receives separated context:

- `tasks` / `actionableTasks`: only real unfinished schedulable tasks
- `allSyncedItems`: full synced context
- `analyticsContext`: grade rows, completed rows, dashboard-only rows
- `personalizationSignals`: aggregated progress signals

This lets the chatbot answer questions about all synced data while not confusing grades or dashboard rows with tasks.

## Dashboard Changes

Updated files:

- `frontend/lib/services/dashboard_metrics_service.dart`
- `frontend/lib/screens/progress_dashboard_screen.dart`

Dashboard task metrics now count real task-like rows only. Grade rows and dashboard-only rows no longer inflate pending/missed/completion counts.

Grades are still available as grade analytics, so the dashboard can remain realistic without confusing grade rows with tasks.

Also, no-deadline synthetic dates no longer appear as real due dates in dashboard drill-downs.

## Tests Added

Added backend tests:

- `backend/tests/test_task_filter.py`
- `backend/tests/test_planner_priority.py`

Covered cases include:

- fake grade/quiz/rubric rows are filtered out
- real assignments are preserved
- stale client metadata cannot force fake rows into the AI plan
- no-deadline assignments are low priority
- missed assignments are urgent priority

## Validation Status

Validated with:

```powershell
python -m unittest discover backend\tests
python -m py_compile ai\task_filter.py ai\chat_service.py backend\app\api\routes\planner.py backend\app\api\routes\chat.py
dart format ...
flutter analyze
```

Current validation result:

- Backend tests pass.
- Python compile checks pass.
- Dart formatting passes.
- Flutter analyze reports only existing unrelated info-level lint warnings in `device_pairing_screen.dart` and `edit_profile_screen.dart`.

## Current Expected Behavior

Study Plan should now:

- include only real unfinished tasks
- include missed assignments
- mark missed assignments as urgent
- mark no-deadline assignments as low
- exclude grade/rubric/assessment/quiz/marking/dashboard rows
- show a readable task table before the AI scenario
- protect against bad AI output by backend validation and fallback insertion

Chatbot should now:

- answer using all synced context
- personalize with grades and progress
- only schedule/prioritize actionable unfinished tasks

Dashboard should now:

- show realistic task progress
- keep grade analytics separate from task completion analytics
- avoid counting fake Classroom rows as missed/pending tasks
