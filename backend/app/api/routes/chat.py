"""
Chat API Routes
Handles AI chatbot interactions using Llama 3.3
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import sys
import os

# Add AI service to path
current_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(current_dir))))
ai_path = os.path.join(backend_dir, 'ai')
sys.path.insert(0, ai_path)

try:
    from chat_service import AIChatService
    chat_service = AIChatService()
    print("✅ Chat service initialized successfully")
except Exception as e:
    print(f"⚠️  Warning: Could not initialize chat service: {e}")
    print(f"   AI path attempted: {ai_path}")
    chat_service = None

router = APIRouter(prefix="/chat", tags=["chat"])


class ChatMessage(BaseModel):
    """Chat message model"""
    role: str  # 'user' or 'assistant'
    content: str


class ChatRequest(BaseModel):
    """Chat request payload"""
    message: str
    conversation_history: Optional[List[ChatMessage]] = None
    student_context: Optional[Dict[str, Any]] = None


class ChatResponse(BaseModel):
    """Chat response model"""
    success: bool
    message: str
    model: Optional[str] = None
    suggestions: Optional[List[str]] = None
    error: Optional[str] = None


@router.post("/message", response_model=ChatResponse)
async def send_message(request: ChatRequest):
    """
    Send a message to the AI chatbot and get a response
    
    Uses Llama 3.3 via Groq API for intelligent responses
    """
    if not chat_service:
        raise HTTPException(
            status_code=503,
            detail="Chat service is not available"
        )
    
    try:
        # Convert conversation history to dict format
        history = None
        if request.conversation_history:
            history = [
                {"role": msg.role, "content": msg.content}
                for msg in request.conversation_history
            ]
        
        # Get AI response
        result = chat_service.chat(
            user_message=request.message,
            conversation_history=history,
            student_context=request.student_context
        )
        
        # Get suggestions
        suggestions = chat_service.get_quick_suggestions(request.student_context)
        
        return ChatResponse(
            success=result.get("success", False),
            message=result.get("message", ""),
            model=result.get("model"),
            suggestions=suggestions,
            error=result.get("error")
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Chat service error: {str(e)}"
        )


@router.get("/suggestions")
async def get_suggestions(
    has_urgent_tasks: bool = False,
    has_upcoming_deadline: bool = False
):
    """
    Get quick suggestion prompts for the user
    """
    if not chat_service:
        return {
            "suggestions": [
                "What should I study now?",
                "Help me prioritize my tasks",
                "I'm feeling overwhelmed"
            ]
        }
    
    context = {
        "urgent_tasks": has_urgent_tasks,
        "upcoming_deadline": has_upcoming_deadline
    }
    
    suggestions = chat_service.get_quick_suggestions(context)
    
    return {"suggestions": suggestions}


@router.get("/health")
async def chat_health():
    """Check if chat service is working"""
    if not chat_service:
        return {
            "status": "unavailable",
            "service": "none"
        }
    
    return {
        "status": "ok",
        "service": "llama-3.3-70b-versatile",
        "provider": "groq"
    }
