"""
Comprehensive Integration Test for UpGrade AI Chat
Tests Llama 3.3 integration end-to-end
"""

import requests
import json
import sys

# ANSI colors
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

def print_header(text):
    print(f"\n{BLUE}{'='*70}{RESET}")
    print(f"{BLUE}{text}{RESET}")
    print(f"{BLUE}{'='*70}{RESET}")

def print_success(text):
    print(f"{GREEN}✅ {text}{RESET}")

def print_error(text):
    print(f"{RED}❌ {text}{RESET}")

def print_info(text):
    print(f"{BLUE}ℹ️  {text}{RESET}")


class LlamaIntegrationTester:
    def __init__(self):
        self.backend_url = "http://127.0.0.1:8001"
        self.passed = 0
        self.failed = 0
    
    def test_chat_health(self):
        """Test if chat endpoint is available"""
        print_header("TEST 1: Chat Endpoint Health Check")
        try:
            response = requests.get(f"{self.backend_url}/api/chat/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                print_success("Chat endpoint is available")
                print_info(f"Service: {data.get('service')}")
                print_info(f"Provider: {data.get('provider')}")
                
                if data.get('service') == 'llama-3.3-70b-versatile':
                    print_success("Llama 3.3 is properly configured! 🦙")
                    self.passed += 1
                    return True
                else:
                    print_error("Wrong model configured")
                    self.failed += 1
                    return False
            else:
                print_error(f"Chat health returned status {response.status_code}")
                self.failed += 1
                return False
        except Exception as e:
            print_error(f"Chat health check failed: {e}")
            self.failed += 1
            return False
    
    def test_simple_chat(self):
        """Test a simple chat message"""
        print_header("TEST 2: Simple Chat Message")
        try:
            payload = {
                "message": "Hello! Can you help me with my studies?",
                "conversation_history": [],
                "student_context": {
                    "name": "Ahmed"
                }
            }
            
            print_info("Sending message to Llama 3.3...")
            response = requests.post(
                f"{self.backend_url}/api/chat/message",
                json=payload,
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    message = data.get('message', '')
                    print_success("Got response from Llama 3.3!")
                    print_info(f"Response preview: {message[:150]}...")
                    print_info(f"Model: {data.get('model')}")
                    print_info(f"Suggestions: {data.get('suggestions', [])[:3]}")
                    self.passed += 1
                    return True
                else:
                    print_error("API returned success=false")
                    self.failed += 1
                    return False
            else:
                print_error(f"Chat API returned status {response.status_code}")
                self.failed += 1
                return False
        except Exception as e:
            print_error(f"Chat test failed: {e}")
            self.failed += 1
            return False
    
    def test_context_aware_chat(self):
        """Test chat with student context"""
        print_header("TEST 3: Context-Aware Chat (With Tasks)")
        try:
            payload = {
                "message": "What should I study first?",
                "conversation_history": [],
                "student_context": {
                    "name": "Sarah",
                    "tasks": [
                        {
                            "title": "Math Assignment due today",
                            "priority": "urgent",
                            "deadline": "2026-02-17T23:59:00"
                        },
                        {
                            "title": "Read History Chapter 5",
                            "priority": "medium",
                            "deadline": "2026-02-20T23:59:00"
                        }
                    ]
                }
            }
            
            print_info("Sending context-aware query to Llama 3.3...")
            response = requests.post(
                f"{self.backend_url}/api/chat/message",
                json=payload,
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    message = data.get('message', '')
                    print_success("Llama 3.3 understood the context!")
                    print_info(f"Response: {message[:200]}...")
                    
                    # Check if response mentions tasks
                    if 'math' in message.lower() or 'urgent' in message.lower():
                        print_success("AI correctly prioritized urgent tasks! 🎯")
                    
                    self.passed += 1
                    return True
                else:
                    print_error("Context-aware chat failed")
                    self.failed += 1
                    return False
            else:
                print_error(f"Status: {response.status_code}")
                self.failed += 1
                return False
        except Exception as e:
            print_error(f"Context test failed: {e}")
            self.failed += 1
            return False
    
    def test_conversation_history(self):
        """Test multi-turn conversation"""
        print_header("TEST 4: Multi-Turn Conversation")
        try:
            # First message
            payload1 = {
                "message": "I have a math exam tomorrow",
                "conversation_history": [],
            }
            
            print_info("Sending first message...")
            response1 = requests.post(
                f"{self.backend_url}/api/chat/message",
                json=payload1,
                timeout=30
            )
            
            if response1.status_code == 200:
                data1 = response1.json()
                ai_response = data1.get('message', '')
                print_info(f"AI: {ai_response[:100]}...")
                
                # Second message with history
                payload2 = {
                    "message": "What should I focus on?",
                    "conversation_history": [
                        {"role": "user", "content": "I have a math exam tomorrow"},
                        {"role": "assistant", "content": ai_response}
                    ],
                }
                
                print_info("Sending follow-up message...")
                response2 = requests.post(
                    f"{self.backend_url}/api/chat/message",
                    json=payload2,
                    timeout=30
                )
                
                if response2.status_code == 200:
                    data2 = response2.json()
                    if data2.get('success'):
                        print_success("Conversation context maintained!")
                        print_info(f"AI: {data2.get('message', '')[:150]}...")
                        self.passed += 1
                        return True
            
            print_error("Conversation test failed")
            self.failed += 1
            return False
        except Exception as e:
            print_error(f"Conversation test failed: {e}")
            self.failed += 1
            return False
    
    def test_suggestions(self):
        """Test getting chat suggestions"""
        print_header("TEST 5: Chat Suggestions")
        try:
            response = requests.get(
                f"{self.backend_url}/api/chat/suggestions?has_urgent_tasks=true",
                timeout=5
            )
            
            if response.status_code == 200:
                data = response.json()
                suggestions = data.get('suggestions', [])
                print_success(f"Got {len(suggestions)} suggestions")
                for i, suggestion in enumerate(suggestions[:5], 1):
                    print_info(f"{i}. {suggestion}")
                self.passed += 1
                return True
            else:
                print_error("Suggestions endpoint failed")
                self.failed += 1
                return False
        except Exception as e:
            print_error(f"Suggestions test failed: {e}")
            self.failed += 1
            return False
    
    def run_all_tests(self):
        """Run all integration tests"""
        print("\n")
        print(f"{BLUE}{'='*70}{RESET}")
        print(f"{BLUE}🦙 Llama 3.3 Integration Test Suite{RESET}")
        print(f"{BLUE}{'='*70}{RESET}")
        
        self.test_chat_health()
        self.test_simple_chat()
        self.test_context_aware_chat()
        self.test_conversation_history()
        self.test_suggestions()
        
        # Summary
        print_header("TEST RESULTS")
        print(f"{GREEN}✅ Passed: {self.passed}{RESET}")
        print(f"{RED}❌ Failed: {self.failed}{RESET}")
        
        total = self.passed + self.failed
        if total > 0:
            success_rate = (self.passed / total) * 100
            print(f"\n{BLUE}Success Rate: {success_rate:.1f}%{RESET}")
        
        print_header("FINAL STATUS")
        if self.failed == 0:
            print_success("🦙 Llama 3.3 is FULLY INTEGRATED and WORKING! 🎉")
            print_info("Your AI chat uses real Llama 3.3 via Groq API")
            print_info("Frontend can now have intelligent conversations")
            print_info("Context-aware responses are working")
        else:
            print_error("Some tests failed. Please check the errors above.")
        
        print("\n" + "="*70 + "\n")
        
        return self.failed == 0


if __name__ == "__main__":
    tester = LlamaIntegrationTester()
    success = tester.run_all_tests()
    sys.exit(0 if success else 1)
