@echo off
TITLE Signify - Launcher

echo ==========================================
echo    SIGNIFY - AI GESTURE RECOGNITION
echo ==========================================
echo.

:: 1. Start the FastAPI Backend in a new window
echo [1/2] Starting AI Backend (FastAPI)...
start "Signify Backend" cmd /k "cd /d C:\Users\Raghavendra\Desktop\Signify\Model\Hand-Sign-Recognition && venv_new\Scripts\python.exe -m uvicorn api:app --reload"

:: 2. Wait a few seconds for the backend to initialize
echo Waiting for backend to warm up...
timeout /t 5 /nobreak > nul

:: 3. Start the Flutter Frontend in the current window
echo [2/2] Starting Flutter Frontend (Chrome)...
cd /d C:\Users\Raghavendra\Desktop\Signify\Frontend\Signify
flutter run -d chrome

pause
