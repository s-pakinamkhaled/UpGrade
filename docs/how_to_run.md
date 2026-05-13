# How to run the Backend
# Open a terminal and run:
cd "C:\Users\HD  TECH\UpGrade_fixes\backend"
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8001
# API docs: http://127.0.0.1:8001/docs


# How to run the Frontend
# Open a NEW terminal and run:
cd "C:\Users\HD  TECH\UpGrade_fixes\frontend"
flutter run -d web-server --web-port 5000 --web-hostname localhost
# Then open http://localhost:5000 in Chrome/Edge
#
# IMPORTANT: Use --web-hostname localhost (NOT 127.0.0.1)
# Google OAuth only accepts "localhost" as a dev origin.
# 127.0.0.1 causes "Error 400: origin_mismatch".


# Fix Google OAuth "origin_mismatch" error (one-time setup)
# ----------------------------------------------------------
# 1. Go to https://console.cloud.google.com/apis/credentials
# 2. Click on your OAuth 2.0 Client ID:
#      476917880453-4s3vkspma7mnt83rkpnlo0mg2rnskvfm.apps.googleusercontent.com
# 3. Under "Authorized JavaScript origins" add ALL of these:
#      http://localhost:3000
#      http://localhost:5000
# 4. Under "Authorized redirect URIs" add ALL of these:
#      http://localhost:3000
#      http://localhost:5000
# 5. Click Save and wait ~5 minutes for changes to propagate.
