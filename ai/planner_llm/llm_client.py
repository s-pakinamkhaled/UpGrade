"""
LLM Client for DeepSeek R1 Integration
Handles communication with DeepSeek R1 API for generating personalized study plans
"""

import os
import json
from typing import Dict, Any, Optional
import requests
from requests.exceptions import RequestException, Timeout


class DeepSeekLLMClient:
    """Client for DeepSeek R1 LLM API"""
    
    def __init__(
        self,
        api_key: Optional[str] = None,
        api_base_url: Optional[str] = None,
        model: str = "deepseek-reasoner",
        timeout: int = 60
    ):
        """
        Initialize DeepSeek LLM Client
        
        Args:
            api_key: DeepSeek API key (or set DEEPSEEK_API_KEY env var)
            api_base_url: API base URL (defaults to DeepSeek's official endpoint)
            model: Model name to use
            timeout: Request timeout in seconds
        """
        self.api_key = api_key or os.getenv("DEEPSEEK_API_KEY")
        self.api_base_url = api_base_url or os.getenv(
            "DEEPSEEK_API_BASE",
            "https://api.deepseek.com/v1"
        )
        self.model = model
        self.timeout = timeout
        
        if not self.api_key:
            print("⚠️  Warning: No API key provided. Set DEEPSEEK_API_KEY environment variable.")
    
    def chat_completion(
        self,
        messages: list,
        temperature: float = 0.7,
        max_tokens: int = 4000,
        stream: bool = False
    ) -> Dict[str, Any]:
        """
        Send chat completion request to DeepSeek API
        
        Args:
            messages: List of message dictionaries with 'role' and 'content'
            temperature: Sampling temperature (0.0 to 1.0)
            max_tokens: Maximum tokens in response
            stream: Whether to stream the response
            
        Returns:
            API response dictionary
        """
        if not self.api_key:
            return self._mock_response(messages)
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": stream
        }
        
        try:
            response = requests.post(
                f"{self.api_base_url}/chat/completions",
                headers=headers,
                json=payload,
                timeout=self.timeout
            )
            
            response.raise_for_status()
            return response.json()
            
        except Timeout:
            print("❌ Request timed out")
            return self._error_response("Request timed out")
            
        except RequestException as e:
            print(f"❌ API request failed: {str(e)}")
            return self._error_response(str(e))
    
    def generate_study_plan(
        self,
        student_data: Dict[str, Any],
        system_prompt: str,
        user_prompt: str
    ) -> Dict[str, Any]:
        """
        Generate personalized study plan from student data
        
        Args:
            student_data: Complete student data dictionary
            system_prompt: System instructions for the LLM
            user_prompt: User prompt template (will be formatted with data)
            
        Returns:
            Study plan response from LLM
        """
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ]
        
        print(f"🤖 Generating study plan for {student_data['student_profile']['name']}...")
        
        response = self.chat_completion(messages, temperature=0.7, max_tokens=4000)
        
        if "error" in response:
            print(f"❌ Error generating plan: {response['error']}")
            return response
        
        return self._parse_study_plan_response(response)
    
    def _parse_study_plan_response(self, api_response: Dict[str, Any]) -> Dict[str, Any]:
        """Parse the API response and extract the study plan"""
        try:
            if "choices" in api_response and len(api_response["choices"]) > 0:
                content = api_response["choices"][0]["message"]["content"]
                
                return {
                    "success": True,
                    "study_plan": content,
                    "raw_response": api_response,
                    "usage": api_response.get("usage", {})
                }
            else:
                return {
                    "success": False,
                    "error": "Invalid API response format",
                    "raw_response": api_response
                }
                
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to parse response: {str(e)}",
                "raw_response": api_response
            }
    
    def _mock_response(self, messages: list) -> Dict[str, Any]:
        """Generate mock response when no API key is provided"""
        print("⚠️  Running in MOCK MODE (no API key)")
        
        mock_plan = """
# 📅 Personalized Study Plan

## 🎯 Priority Tasks (Next 48 Hours)

### 1. Data Mining Quiz 1 – Classification
- **Deadline**: TODAY or Tomorrow
- **Estimated Time**: 2 hours
- **Recommended Slot**: Today 18:00-20:00
- **Priority**: HIGH ⚠️
- **Action**: Review classification algorithms, practice problems

### 2. Artificial Intelligence Assignment 2 – Search Algorithms
- **Deadline**: 2 days
- **Estimated Time**: 4 hours
- **Progress**: 20% complete
- **Recommended Slots**:
  - Today 20:00-22:00 (2 hours)
  - Tomorrow 18:00-20:00 (2 hours)
- **Priority**: HIGH ⚠️
- **Action**: Complete remaining 80% - focus on implementation

## 📊 Weekly Schedule Optimization

### Saturday
- 18:00-20:00: AI Assignment (2 hours)
- 20:00-20:10: Break
- 20:10-22:00: Data Mining Quiz prep (1.5 hours)

### Sunday
- 18:00-20:00: AI Assignment completion (2 hours)
- 20:00-20:10: Break
- 20:10-22:00: Review and test

### Monday-Thursday
- Continue with medium priority tasks
- Review sessions for upcoming assessments
- Maintain steady pace (2-3 hours/day)

## 🎯 Strategic Recommendations

1. **Focus on AI401 & DS312** - These are your high-risk courses
2. **Improve attendance** - DS312 attendance is at 70%, aim for 85%+
3. **Use peak hours** - Your best focus is 18:00-22:00
4. **Break pattern**: Study 50 min → Break 10 min
5. **Reduce late submissions** - Current rate is 25%, aim for <10%

## ⚠️ Risk Alerts

- **High Risk**: AI401 (score: 78) - Needs immediate attention
- **Medium Risk**: DS312 (score: 45) - Manageable with consistent effort
- **Workload Alert**: Next week has 14 hours of work - start early!

## 💡 Study Tips

1. Start with hardest task (AI Assignment) when energy is highest
2. Break large tasks into 2-hour chunks
3. Use active recall for Data Mining concepts
4. Practice coding problems daily for AI course
5. Set reminders 24h before each deadline

---
**Generated by UpGrade AI Planner** 🎓
"""
        
        return {
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": mock_plan
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 1500,
                "completion_tokens": 500,
                "total_tokens": 2000
            },
            "model": "mock-model"
        }
    
    def _error_response(self, error_message: str) -> Dict[str, Any]:
        """Create error response dictionary"""
        return {
            "error": error_message,
            "success": False
        }


class OpenAICompatibleClient(DeepSeekLLMClient):
    """
    OpenAI-compatible client for use with other providers
    (e.g., OpenAI, Together AI, Groq, etc.)
    """
    
    def __init__(
        self,
        api_key: Optional[str] = None,
        api_base_url: Optional[str] = "https://api.openai.com/v1",
        model: str = "gpt-4",
        timeout: int = 60
    ):
        super().__init__(api_key, api_base_url, model, timeout)


class GroqClient(DeepSeekLLMClient):
    """
    Groq API client for Llama models
    Fast inference for open-source models like Llama 3.3
    """
    
    def __init__(
        self,
        api_key: Optional[str] = None,
        model: str = "llama-3.3-70b-versatile",
        timeout: int = 60
    ):
        """
        Initialize Groq client
        
        Args:
            api_key: Groq API key (or set GROQ_API_KEY env var)
            model: Model name (default: llama-3.3-70b-versatile)
            timeout: Request timeout in seconds
        """
        groq_api_key = api_key or os.getenv("GROQ_API_KEY")
        groq_base_url = os.getenv("GROQ_API_BASE", "https://api.groq.com/openai/v1")
        groq_model = os.getenv("GROQ_MODEL", model)
        
        super().__init__(groq_api_key, groq_base_url, groq_model, timeout)
        
        if not self.api_key:
            print("⚠️  Warning: No Groq API key provided. Set GROQ_API_KEY environment variable.")


def test_client():
    """Test the LLM client"""
    client = DeepSeekLLMClient()
    
    # Simple test
    messages = [
        {"role": "system", "content": "You are a helpful study planning assistant."},
        {"role": "user", "content": "Create a study plan for tomorrow."}
    ]
    
    response = client.chat_completion(messages)
    print(json.dumps(response, indent=2))


if __name__ == "__main__":
    test_client()
