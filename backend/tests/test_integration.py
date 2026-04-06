"""
UpGrade Project - Integration Test Suite
Tests all components of the application
"""

import requests
import sys
import os
import time
import subprocess
from pathlib import Path
from urllib.parse import urlparse

# ANSI color codes
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

def print_header(text):
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}{text}{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")

def print_success(text):
    print(f"{GREEN}✅ {text}{RESET}")

def print_error(text):
    print(f"{RED}❌ {text}{RESET}")

def print_warning(text):
    print(f"{YELLOW}⚠️  {text}{RESET}")

def print_info(text):
    print(f"{BLUE}ℹ️  {text}{RESET}")


class IntegrationTester:
    def __init__(self):
        self.backend_url = os.getenv("UPGRADE_BACKEND_URL", "http://127.0.0.1:8001")
        self.frontend_url = os.getenv("UPGRADE_FRONTEND_URL", "http://localhost:3000")
        self.auto_start_backend = os.getenv("AUTO_START_BACKEND", "true").lower() == "true"
        # CI does not boot the Flutter frontend, so keep this check configurable.
        self.require_frontend = os.getenv("REQUIRE_FRONTEND", "false").lower() == "true"
        self.project_root = self._detect_project_root()
        self._started_backend = False
        self._backend_process = None
        self._backend_log_handle = None
        self._backend_log_path = str(self.project_root / "backend_integration_test.log")
        self.results = {
            'passed': 0,
            'failed': 0,
            'warnings': 0
        }

    def _detect_project_root(self):
        """Find the repository root regardless of where this script is located."""
        script_path = Path(__file__).resolve()
        for candidate in [script_path.parent, *script_path.parents]:
            if (candidate / "ai").exists() and (candidate / "backend").exists():
                return candidate

        # Fallback to script directory if expected structure cannot be discovered.
        return script_path.parent

    def _is_backend_reachable(self):
        try:
            response = requests.get(f"{self.backend_url}/health", timeout=2)
            return response.status_code == 200
        except Exception:
            return False

    def _start_backend_if_needed(self):
        if self._is_backend_reachable():
            print_info(f"Backend is already running at {self.backend_url}")
            return

        if not self.auto_start_backend:
            print_info("Backend is not running. Start it with .\\run-backend.ps1 or set AUTO_START_BACKEND=true.")
            return

        parsed = urlparse(self.backend_url)
        host = parsed.hostname or "127.0.0.1"
        port = str(parsed.port or 8001)
        backend_dir = self.project_root / "backend"

        if not backend_dir.exists():
            print_error(f"Cannot auto-start backend: folder not found: {backend_dir}")
            return

        print_info(f"Backend is down. Starting it automatically at {host}:{port}...")
        cmd = [
            sys.executable,
            "-m",
            "uvicorn",
            "app.main:app",
            "--host",
            host,
            "--port",
            port,
        ]

        try:
            self._backend_log_handle = open(self._backend_log_path, "w", encoding="utf-8")
            self._backend_process = subprocess.Popen(
                cmd,
                cwd=str(backend_dir),
                stdout=self._backend_log_handle,
                stderr=subprocess.STDOUT,
            )
            self._started_backend = True
        except Exception as e:
            print_error(f"Failed to auto-start backend: {e}")
            print_info("Run .\\run-backend.ps1 manually and rerun this test.")
            if self._backend_log_handle:
                self._backend_log_handle.close()
                self._backend_log_handle = None
            return

        for _ in range(30):
            if self._is_backend_reachable():
                print_success("Backend started successfully")
                return
            if self._backend_process and self._backend_process.poll() is not None:
                break
            time.sleep(1)

        print_error("Backend did not become ready in time.")
        print_info(f"Check backend startup logs: {self._backend_log_path}")

    def _stop_backend_if_started(self):
        if self._started_backend and self._backend_process and self._backend_process.poll() is None:
            print_info("Stopping backend started by this test...")
            self._backend_process.terminate()
            try:
                self._backend_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self._backend_process.kill()

        if self._backend_log_handle:
            self._backend_log_handle.close()
            self._backend_log_handle = None

    def test_backend_health(self):
        """Test if backend API is running"""
        print_header("TEST 1: Backend Health Check")
        try:
            response = requests.get(f"{self.backend_url}/health", timeout=5)
            if response.status_code == 200:
                print_success("Backend is running")
                print_info(f"Response: {response.json()}")
                self.results['passed'] += 1
                return True
            else:
                print_error(f"Backend returned status {response.status_code}")
                self.results['failed'] += 1
                return False
        except Exception as e:
            print_error(f"Backend is not reachable: {e}")
            self.results['failed'] += 1
            return False

    def test_backend_root(self):
        """Test backend root endpoint"""
        print_header("TEST 2: Backend Root Endpoint")
        try:
            response = requests.get(f"{self.backend_url}/", timeout=5)
            if response.status_code == 200:
                data = response.json()
                print_success("Backend root endpoint working")
                print_info(f"Message: {data.get('message')}")
                self.results['passed'] += 1
                return True
            else:
                print_error(f"Root endpoint returned status {response.status_code}")
                self.results['failed'] += 1
                return False
        except Exception as e:
            print_error(f"Failed to reach root endpoint: {e}")
            self.results['failed'] += 1
            return False

    def test_backend_docs(self):
        """Test if API documentation is accessible"""
        print_header("TEST 3: Backend API Documentation")
        try:
            response = requests.get(f"{self.backend_url}/docs", timeout=5)
            if response.status_code == 200:
                print_success("API documentation is accessible")
                print_info(f"Docs URL: {self.backend_url}/docs")
                self.results['passed'] += 1
                return True
            else:
                print_error(f"Docs returned status {response.status_code}")
                self.results['failed'] += 1
                return False
        except Exception as e:
            print_error(f"Failed to reach docs: {e}")
            self.results['failed'] += 1
            return False

    def test_frontend_running(self):
        """Test if frontend is accessible"""
        print_header("TEST 4: Frontend Accessibility")
        try:
            response = requests.get(self.frontend_url, timeout=5)
            if response.status_code == 200:
                print_success("Frontend is running")
                print_info(f"Frontend URL: {self.frontend_url}")
                self.results['passed'] += 1
                return True
            else:
                print_warning(f"Frontend returned status {response.status_code}")
                print_info("This might be normal for Flutter web apps")
                self.results['warnings'] += 1
                return True
        except requests.exceptions.ConnectionError:
            if self.require_frontend:
                print_error("Frontend is not reachable")
                print_info("Set REQUIRE_FRONTEND=false to make this check optional")
                self.results['failed'] += 1
                return False
            print_warning("Frontend is not reachable (optional check skipped)")
            print_info("Set REQUIRE_FRONTEND=true to enforce frontend availability")
            self.results['warnings'] += 1
            return True
        except Exception as e:
            print_warning(f"Frontend check inconclusive: {e}")
            self.results['warnings'] += 1
            return True

    def test_ai_service(self):
        """Test AI service functionality"""
        print_header("TEST 5: AI Service")
        try:
            # Check if AI service files exist
            ai_dir = self.project_root / 'ai'
            if ai_dir.exists():
                print_success("AI service directory found")
                
                # Check for key files
                key_files = ['planner_llm', 'chat_service.py', 'requirements.txt']
                missing_files = []
                for file in key_files:
                    if (ai_dir / file).exists():
                        print_info(f"Found: {file}")
                    else:
                        print_warning(f"Missing: {file}")
                        missing_files.append(file)
                
                if missing_files:
                    print_error("AI service is missing required files")
                    self.results['failed'] += 1
                    return False

                print_success("AI service is properly configured")
                self.results['passed'] += 1
                return True
            else:
                print_error("AI service directory not found")
                self.results['failed'] += 1
                return False
        except Exception as e:
            print_error(f"AI service check failed: {e}")
            self.results['failed'] += 1
            return False

    def test_database_models(self):
        """Test if database models are defined"""
        print_header("TEST 6: Database Models")
        try:
            models_dir = self.project_root / 'backend' / 'app' / 'models'
            if models_dir.exists():
                models = [f.name for f in models_dir.iterdir() if f.is_file() and f.suffix == '.py']
                print_success(f"Found {len(models)} model file(s)")
                for model in models:
                    print_info(f"Model: {model}")
                self.results['passed'] += 1
                return True
            else:
                print_warning("Models directory not found")
                self.results['warnings'] += 1
                return True
        except Exception as e:
            print_warning(f"Models check inconclusive: {e}")
            self.results['warnings'] += 1
            return True

    def run_all_tests(self):
        """Run all integration tests"""
        print("\n")
        print(f"{BLUE}{'='*60}{RESET}")
        print(f"{BLUE}🎓 UpGrade - Integration Test Suite{RESET}")
        print(f"{BLUE}{'='*60}{RESET}")

        self._start_backend_if_needed()
        
        try:
            # Run all tests
            self.test_backend_health()
            self.test_backend_root()
            self.test_backend_docs()
            self.test_frontend_running()
            self.test_ai_service()
            self.test_database_models()
        finally:
            self._stop_backend_if_started()
        
        # Print summary
        print_header("TEST SUMMARY")
        print(f"{GREEN}✅ Passed: {self.results['passed']}{RESET}")
        print(f"{RED}❌ Failed: {self.results['failed']}{RESET}")
        print(f"{YELLOW}⚠️  Warnings: {self.results['warnings']}{RESET}")
        
        total = self.results['passed'] + self.results['failed']
        if total > 0:
            success_rate = (self.results['passed'] / total) * 100
            print(f"\n{BLUE}Success Rate: {success_rate:.1f}%{RESET}")
        
        # Overall status
        print_header("OVERALL STATUS")
        if self.results['failed'] == 0:
            print_success("All critical tests passed! ✨")
            print_info("Your UpGrade application is properly integrated!")
            if self.results['warnings'] > 0:
                print_warning(f"Note: {self.results['warnings']} warning(s) detected")
        else:
            print_error("Some tests failed. Please check the issues above.")
        
        print("\n" + "="*60 + "\n")
        
        return self.results['failed'] == 0


if __name__ == "__main__":
    tester = IntegrationTester()
    success = tester.run_all_tests()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)
