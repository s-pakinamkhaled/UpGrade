# 🎓 UpGrade AI Service - Quick Start Guide

## What's Implemented

✅ **Complete AI Service** for generating personalized study plans using Llama 3.3 via Groq API

### Components Created:

1. **Data Generator** ([data/data_generator.py](data/data_generator.py))
   - Generates realistic fake student data
   - Includes: profile, courses, tasks, grades, attendance, availability, productivity patterns
   
2. **LLM Client** ([planner_llm/llm_client.py](planner_llm/llm_client.py))
   - Groq API integration (Llama 3.3)
   - DeepSeek and OpenAI support
   - Mock mode for testing without API key
   
3. **Prompt System** ([planner_llm/prompt.py](planner_llm/prompt.py))
   - System prompt for AI assistant
   - User prompt templates that format student data
   - Comprehensive context building
   
4. **Main Service** ([ai_service.py](ai_service.py))
   - Coordinates data generation and LLM calls
   - Saves outputs to files
   - Provides demo mode

## 🚀 How to Run

### Option 1: Quick Test (No Setup)

```powershell
cd ai
python test_service.py
```

This will run in **MOCK MODE** (no API key needed) and:
- Generate fake student data
- Create example study plans
- Save outputs to `output/` folder

### Option 2: Full Demo

```powershell
cd ai
python ai_service.py
```

### Option 3: With Real Groq API (Llama 3.3)

✅ **Already Configured!** The `.env` file is set up with Groq API.

1. Install dependencies (if not done):
```powershell
pip install -r requirements.txt
```

2. Run with real LLM:
```powershell
python ai_service.py
# or
python test_service.py
```

The service will automatically use:
- **Provider**: Groq
- **Model**: Llama 3.3 (70B)
- **API Key**: From `.env` file

### Option 4: Switch to Different Provider

Edit `.env` to change providers:

**For DeepSeek:**
```env
LLM_PROVIDER=deepseek
DEEPSEEK_API_KEY=your_key_here
```

**For OpenAI:**
```env
LLM_PROVIDER=openai
OPENAI_API_KEY=your_key_here
```

## 📁 Output Files

After running, check:

- `output/study_plan_S-2026-XXX.md` - Human-readable study plan
- `output/response_S-2026-XXX.json` - Full API response
- `data/generated_student_data.json` - Generated student data

## 🔧 Usage in Your Code

```python
from ai.ai_service import UpGradeAIService

# Initialize service
service = UpGradeAIService(api_key="your_key")

# Generate fake data
student_data = service.generate_fake_student_data()

# Or load existing data
student_data = service.load_student_data("data/sample_student.json")

# Generate study plan
result = service.generate_study_plan(student_data)

print(result['study_plan'])
```

## 📊 What the Study Plan Includes

- **Priority Tasks** for next 48-72 hours
- **Daily Schedule** matched to student's availability
- **Weekly Optimization** 
- **Risk Alerts** for high-risk courses
- **Strategic Recommendations**
- **Study Tips** tailored to student's patterns
- **Break Schedules** based on productivity patterns

## 🎯 Key Features

✅ Generates realistic fake student data in exact JSON format you provided
✅ Integrates with DeepSeek R1 LLM
✅ Works in mock mode without API key
✅ Saves study plans as Markdown and JSON
✅ Analyzes risk levels per course
✅ Optimizes for student's availability and productivity
✅ Prioritizes tasks by urgency and importance

## 💡 Next Steps

1. Test it: `python test_service.py`
2. Review generated plans in `output/` folder
3. Customize prompts in `planner_llm/prompt.py`
4. Integrate with your backend API
5. Get DeepSeek API key for real LLM calls

## 🔗 Integration with Backend

To use this in your FastAPI backend:

```python
# In backend/app/services/ai_planner_service.py
import sys
sys.path.append('../ai')

from ai.ai_service import UpGradeAIService

class AIPlannerService:
    def __init__(self):
        self.ai = UpGradeAIService(
            api_key=settings.DEEPSEEK_API_KEY
        )
    
    async def generate_plan(self, user_id: str):
        # Fetch user data from database
        student_data = await self.get_user_data(user_id)
        
        # Generate plan
        result = self.ai.generate_study_plan(student_data)
        
        return result['study_plan']
```

## 📚 Documentation

See [README.md](README.md) for full documentation.

---

**Everything is ready to use! Try it now!** 🚀
