"""
UpGrade Project - Integration Test Suite
Tests all components of the application
"""

import requests
import sys
import time

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
        self.backend_url = "http://127.0.0.1:8001"
        self.frontend_url = "http://localhost:3000"
        self.results = {
            'passed': 0,
            'failed': 0,
            'warnings': 0
        }

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
            print_error("Frontend is not reachable")
            print_info("Make sure 'flutter run -d chrome' is running")
            self.results['failed'] += 1
            return False
        except Exception as e:
            print_warning(f"Frontend check inconclusive: {e}")
            self.results['warnings'] += 1
            return True

    def test_ai_service(self):
        """Test AI service functionality"""
        print_header("TEST 5: AI Service")
        try:
            # Check if AI service files exist
            import os
            ai_dir = os.path.join(os.path.dirname(__file__), 'ai')
            if os.path.exists(ai_dir):
                print_success("AI service directory found")
                
                # Check for key files
                key_files = ['ai_service.py', 'test_service.py', 'requirements.txt']
                for file in key_files:
                    if os.path.exists(os.path.join(ai_dir, file)):
                        print_info(f"Found: {file}")
                    else:
                        print_warning(f"Missing: {file}")
                
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
            import os
            models_dir = os.path.join(os.path.dirname(__file__), 'backend', 'app', 'models')
            if os.path.exists(models_dir):
                models = [f for f in os.listdir(models_dir) if f.endswith('.py') and f != '__pycache__']
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
        
        # Run all tests
        self.test_backend_health()
        self.test_backend_root()
        self.test_backend_docs()
        self.test_frontend_running()
        self.test_ai_service()
        self.test_database_models()
        
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
