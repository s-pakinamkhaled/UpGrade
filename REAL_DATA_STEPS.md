# Using Real Google Classroom Data (What Was Done)

The app now uses **your real Classroom data** instead of fixed demo data. Here’s what was implemented and how it works.

---

## 1. **Google Classroom API data**

When you tap **Sync Now** on the Google Classroom sync screen, the app:

- Calls **Google Classroom API** with your Google account.
- Fetches:
  - **Courses** you’re enrolled in (as student).
  - **Course work** (assignments) per course: **title**, **description**, **due date/time**, **max points**.
  - **Your submissions** per assignment: **state** (e.g. turned in, returned), **assigned grade**, **draft grade**, **late**.
- Groups everything by course and maps it into in-app **courses** and **tasks**.

So the app gets: **assignment names**, **deadlines**, **grades** (when returned by the teacher), and **submission status** from Classroom.

---

## 2. **Models (Classroom → app)**

- **`ClassroomCourse`** – id, name, section, description (from Classroom course).
- **`ClassroomAssignment`** – id, courseId, title, description, dueDate, maxPoints (from courseWork).
- **`ClassroomSubmission`** – id, assignmentId, state, assignedGrade, draftGrade, late (from studentSubmissions).
- **`Task`** – extended with **assignedGrade** and **maxPoints** so the planner can show grades.

Assignments are converted to **Tasks** with:

- Title, description, deadline, course name  
- Priority from due date and submission status  
- Status: **completed** if turned in/returned, **missed** if past due and not submitted  
- **assignedGrade** and **maxPoints** when available  

This gives the app everything it needs to build a plan (what, when, how important, and how you did).

---

## 3. **Persistence (data stays after sync)**

- After a successful sync, **courses** and **tasks** are saved locally with **SharedPreferences** (no backend needed).
- On app start, **ClassroomProvider** calls **loadFromStorage()** and fills **courses** and **tasks** from this storage.
- So after you sync once, the planner and weekly view use your data even after closing the app.

---

## 4. **Where the app uses this data**

- **Google Classroom Sync screen**  
  - Uses **ClassroomProvider.syncClassroom(accessToken)**.  
  - Shows loading from provider, then a snackbar like “Synced X assignments from Y courses” and navigates to the next step.

- **Daily Planner**  
  - Reads **ClassroomProvider.tasks**.  
  - Builds a **week map** (date → list of tasks) from task **deadlines**.  
  - Shows “X tasks” in the app bar when synced.  
  - If you never synced: message “Sync Google Classroom to see your assignments and deadlines here.”  
  - If you synced but there are no tasks that week: “No assignments due this week.”

- **Weekly Schedule**  
  - Still receives the same **weekly task map** (date → tasks) built from provider tasks, so it also shows real assignments by day.

So: **sync → data saved → planner and weekly schedule use your real assignments, deadlines, and (when available) grades.**

---

## 5. **Steps for you (user flow)**

1. **Sign in** (email or Google).
2. On the **Google Classroom Sync** screen, tap **Sync Now** and complete Google sign-in if asked.
3. The app fetches your courses and assignments, maps them to tasks (with names, deadlines, grades), and **saves them locally**.
4. Open **Daily Planner** or **Weekly Schedule** – they now show **your** assignments and deadlines; when the teacher has returned a grade, that can be used in the app (e.g. in the task model and any UI you add for grades).
5. **Re-sync** anytime from the same screen (or a future “Sync” in settings) to refresh courses, assignments, and grades.

---

## 6. **Optional next steps**

- **Progress / grades UI** – Use `Task.assignedGrade` and `Task.maxPoints` in the Progress Dashboard or on task cards.
- **“Sync” in settings** – Call `ClassroomProvider.syncClassroom(accessToken)` again (e.g. from a settings or profile screen) and refresh the UI.
- **Filter by course** – Use `ClassroomProvider.courses` and filter `tasks` by `courseId` for a per-course view.
- **Backend** – If you add a backend later, you can also send the synced data (e.g. tasks + grades) to your server after each sync.

You now have a path from **Classroom (name, deadline, grades, submission state)** → **sync** → **local storage** → **planner and weekly view** with no fixed demo data in that flow.
