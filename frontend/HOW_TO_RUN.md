# UpGrade - Complete Startup Guide

## Current Status

✅ **Backend API**: Running on http://127.0.0.1:8001
✅ **AI Service**: Working with Llama 3.3
❌ **Frontend**: Requires Flutter installation

---

## How to Run the Full Application

### Step 1: Backend (Already Running ✅)
Your backend is already running on port 8001.

If you need to restart it:
```powershell
cd backend
python -m uvicorn app.main:app --reload --port 8001
```

### Step 2: AI Service (Already Working ✅)
Test the AI service anytime:
```powershell
cd ai
python test_service.py
```

### Step 3: Frontend (Need to Setup)

#### Option A: Install Flutter on Windows

1. **Download Flutter SDK**
   - Visit: https://docs.flutter.dev/get-started/install/windows
   - Download the latest stable release (Flutter 3.x)

2. **Extract and Setup**
   ```powershell
   # Extract flutter_windows_*.zip to C:\flutter
   # Add to PATH: C:\flutter\bin
   ```

3. **Verify Installation**
   ```powershell
   flutter doctor
   ```

4. **Run the App**
   ```powershell
   cd frontend
   flutter pub get
   flutter run -d chrome
   ```

#### Option B: Quick Install with Chocolatey

If you have Chocolatey package manager:
```powershell
choco install flutter
```

#### Option C: Use Docker (No Flutter Install Needed)

```powershell
cd frontend
docker build -t upgrade-frontend .
docker run -p 8080:80 upgrade-frontend
# Access at: http://localhost:8080
```

---

## Using the Startup Scripts

### After Installing Flutter:

**Windows Batch:**
```cmd
cd frontend
START_APP.bat
```

**PowerShell:**
```powershell
cd frontend
.\START_APP.ps1
```

---

## Common Issues

### "Flutter not recognized"
- Flutter is not installed
- Flutter is not in your PATH
- Need to restart terminal after installation

### "No connected devices"
For web development:
```powershell
flutter config --enable-web
flutter devices
```

### Alternative: Run on Windows Desktop
```powershell
flutter run -d windows
```

---

## Project Architecture

```
UpGrade System
├── Frontend (Flutter/Dart) - Port: varies
│   └── UI Layer
├── Backend (FastAPI) - Port: 8001
│   └── REST API
└── AI Service (Python)
    └── Groq API (Llama 3.3)
```

---

## Resources

- Flutter Installation: https://docs.flutter.dev/get-started/install
- Flutter Web: https://docs.flutter.dev/platform-integration/web
- Project README: ../README.md
- AI Service Guide: ../ai/QUICKSTART.md
