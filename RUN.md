# How to Run UpGrade

## Run the whole project (easiest)

From the project root in PowerShell:

```powershell
.\run-all.ps1
```

This opens a **new window** with the backend (FastAPI on port 8001) and runs the **frontend** (Flutter) in the current window. When Flutter asks for a device, pick one (e.g. **Chrome** or **Windows**).

**Requires:** Python and Flutter installed and in PATH.

---

## 1. Backend (FastAPI) – port 8001

**Requires:** Python 3.x with pip in PATH.

```powershell
cd backend
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
```

Or run the script from project root:

```powershell
.\run-backend.ps1
```

Then open: http://127.0.0.1:8001 (API docs: http://127.0.0.1:8001/docs)

---

## 2. Frontend (Flutter)

**Requires:** Flutter SDK in PATH.

```powershell
cd frontend
flutter pub get
flutter run
```

When prompted, choose a device (e.g. **Chrome**, **Windows**, or an attached phone/emulator).

Or run the script from project root:

```powershell
.\run-frontend.ps1
```

---

## 3. Run both

1. Open a terminal and run the **backend** (leave it running).
2. Open another terminal and run the **frontend**.

The app talks to the backend at `http://127.0.0.1:8001`. If the backend is not running, health checks and the AI chatbot may fail.
