"""
AI Chat Service for Real-time Student Assistance
Uses Llama 3.3 via Groq API for conversational support
"""

import os
from typing import List, Dict, Any, Optional
from dotenv import load_dotenv
from planner_llm.llm_client import GroqClient

# Load environment variables
load_dotenv()


class AIChatService:
    """Service for handling AI chat conversations with students"""
    
    def __init__(self):
        """Initialize the chat service with Llama 3.3"""
        provider = os.getenv("LLM_PROVIDER", "groq").lower()
        
        if provider == "groq":
            self.client = GroqClient()
            print("✅ AI Chat Service initialized with Llama 3.3 (Groq)")
        else:
            self.client = GroqClient()  # Default to Groq
            print("✅ AI Chat Service initialized with Llama 3.3 (default)")
        
        self.system_prompt = self._get_system_prompt()
    
    def _get_system_prompt(self) -> str:
        """Get the system prompt for the AI assistant"""
        return """You are an intelligent AI study assistant for UpGrade, a personalized study planning app. Your role is to help students:

1. **Schedule Management**: Help reschedule tasks, suggest study times, and optimize their daily planner
2. **Study Guidance**: Provide study tips, recommend what to study next, and help prioritize tasks
3. **Motivation**: Encourage students, help manage burnout, and provide emotional support
4. **Academic Advice**: Answer questions about learning strategies, time management, and productivity

Guidelines:
- Be friendly, supportive, and encouraging
- Give practical, actionable advice
- Keep responses concise but helpful (2-4 paragraphs max)
- Use emojis sparingly for emphasis 📚 ✨
- If asked about specific tasks, provide relevant recommendations
- Help students stay focused and motivated

Remember: You're a study companion, not just a chatbot. Be personal and understanding."""
    
    def chat(
        self,
        user_message: str,
        conversation_history: Optional[List[Dict[str, str]]] = None,
        student_context: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Process a chat message and generate AI response
        
        Args:
            user_message: The user's message
            conversation_history: Previous messages in the conversation
            student_context: Optional context about the student (tasks, schedule, etc.)
            
        Returns:
            Dictionary with AI response and metadata
        """
        try:
            # Build message history
            messages = [{"role": "system", "content": self.system_prompt}]
            
            # Add context if provided
            if student_context:
                context_msg = self._build_context_message(student_context)
                if context_msg:
                    messages.append({"role": "system", "content": context_msg})
            
            # Add conversation history
            if conversation_history:
                messages.extend(conversation_history[-10:])  # Keep last 10 messages
            
            # Add current user message
            messages.append({"role": "user", "content": user_message})
            
            # Get AI response
            print(f"💬 Processing chat message: {user_message[:50]}...")
            response = self.client.chat_completion(
                messages=messages,
                temperature=0.7,
                max_tokens=500  # Shorter responses for chat
            )
            
            # Extract response content
            if "choices" in response and len(response["choices"]) > 0:
                ai_message = response["choices"][0]["message"]["content"]
                
                return {
                    "success": True,
                    "message": ai_message,
                    "usage": response.get("usage", {}),
                    "model": response.get("model", "llama-3.3-70b-versatile")
                }
            else:
                return {
                    "success": False,
                    "error": "Failed to get response from AI",
                    "message": "I'm having trouble responding right now. Please try again."
                }
                
        except Exception as e:
            print(f"❌ Error in chat service: {str(e)}")
            return {
                "success": False,
                "error": str(e),
                "message": "I apologize, but I'm experiencing technical difficulties. Please try again in a moment."
            }
    
    def _build_context_message(self, context: Dict[str, Any]) -> str:
        """Build a context message from student data"""
        parts = []
        
        if "name" in context:
            parts.append(f"Student: {context['name']}")
        
        if "tasks" in context and context["tasks"]:
            task_count = len(context["tasks"])
            urgent_count = sum(1 for t in context["tasks"] if t.get("priority") == "urgent")
            parts.append(f"Current tasks: {task_count} total, {urgent_count} urgent")
        
        if "schedule" in context:
            parts.append(f"Today's schedule: {context['schedule']}")
        
        if parts:
            return "Current context:\n" + "\n".join(parts)
        
        return ""
    
    def get_quick_suggestions(self, student_context: Optional[Dict[str, Any]] = None) -> List[str]:
        """
        Get quick suggestion prompts based on student context
        
        Returns:
            List of suggested questions/prompts
        """
        suggestions = [
            "What should I study now?",
            "Help me prioritize my tasks",
            "I'm feeling overwhelmed",
            "How can I improve my focus?",
            "Suggest a study schedule",
        ]
        
        # Add context-specific suggestions
        if student_context:
            if student_context.get("urgent_tasks"):
                suggestions.insert(0, "What urgent tasks should I do first?")
            
            if student_context.get("upcoming_deadline"):
                suggestions.insert(1, "Help me prepare for my deadline")
        
        return suggestions[:5]  # Return top 5


# Test function
def test_chat_service():
    """Test the chat service"""
    print("\n" + "="*60)
    print("🧪 Testing AI Chat Service with Llama 3.3")
    print("="*60 + "\n")
    
    service = AIChatService()
    
    # Test 1: Simple greeting
    print("Test 1: Simple greeting")
    response = service.chat("Hello! Can you help me study?")
    print(f"Response: {response.get('message', 'ERROR')}\n")
    print(f"Model: {response.get('model', 'unknown')}\n")
    
    # Test 2: Study advice
    print("Test 2: Study advice")
    context = {
        "name": "Ahmed",
        "tasks": [
            {"title": "Math Assignment", "priority": "urgent"},
            {"title": "Read History", "priority": "medium"}
        ]
    }
    response = service.chat(
        "What should I study first?",
        student_context=context
    )
    print(f"Response: {response.get('message', 'ERROR')}\n")
    
    # Test 3: Get suggestions
    print("Test 3: Quick suggestions")
    suggestions = service.get_quick_suggestions(context)
    print("Suggestions:", suggestions)
    
    print("\n" + "="*60)
    print("✅ Chat service test completed!")
    print("="*60 + "\n")


if __name__ == "__main__":
    test_chat_service()
