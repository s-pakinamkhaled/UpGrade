# 🎓 UpGrade AI Service

AI-powered study planning service that generates personalized study plans using Llama 3.3 via Groq API.

## 🌟 Features

- **Fake Data Generation**: Create realistic student profiles with courses, tasks, grades, and analytics
- **Llama 3.3 Integration**: Use advanced open-source LLM via Groq for fast, personalized study plans
- **Risk Analysis**: Identify high-risk courses and tasks
- **Schedule Optimization**: Match study plans to student availability and productivity patterns
- **Priority Management**: Intelligently prioritize tasks based on urgency and importance

## 📁 Project Structure

```
ai/
├── ai_service.py              # Main service coordinator
├── requirements.txt           # Python dependencies
├── .env.example              # Environment variables template
├── README.md                 # This file
├── data/
│   ├── data_generator.py     # Fake student data generator
│   └── sample_data.json      # Sample student data
├── planner_llm/
│   ├── llm_client.py         # LLM API client (Groq/DeepSeek/OpenAI)
│   ├── prompt.py             # Prompt templates
│   └── formatter.py          # (if needed)
└── output/                   # Generated study plans
    ├── study_plan_*.md       # Study plans in markdown
    └── response_*.json       # Full API responses
```

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd ai
pip install -r requirements.txt
```

### 2. Configure API Key

Create a `.env` file (copy from `.env.example`):

```bash
cp .env.example .env
```

Edit `.env` and add your Groq API key:

```env
DEEPSEEK_API_KEY=your_actual_api_key_here
```

**Note**: If you don't have an API key, the service will run in **MOCK MODE** and generate example study plans.

### 3. Run the Demo

```bash
python ai_service.py
```

This will:
1. Generate fake student data
2. Call DeepSeek R1 to create a personalized study plan
3. Save the output to `output/` directory

## 💻 Usage Examples

### Generate Fake Student Data Only

```python
from data.data_generator import StudentDataGenerator

generator = StudentDataGenerator()
student_data = generator.generate_complete_student_data()

# Save to file
import json
with open('my_student.json', 'w') as f:
    json.dump(student_data, f, indent=2)
```

### Generate Study Plan with Custom Data

```python
from ai_service import UpGradeAIService

# Initialize service
service = UpGradeAIService(
    api_key="your_api_key",
    model="deepseek-reasoner"
)

# Load student data
student_data = service.load_student_data("data/sample_data.json")

# Generate study plan
result = service.generate_study_plan(student_data)

print(result['study_plan'])
```

### Use OpenAI Instead of DeepSeek

```python
from ai_service import UpGradeAIService

service = UpGradeAIService(
    api_key="your_openai_key",
    model="gpt-4",
    use_openai=True
)

result = service.run_demo()
```

## 📊 Student Data Format

The service expects student data in this structure:

```json
{
  "student_profile": {
    "student_id": "S-2026-001",
    "name": "Ahmed Hassan",
    "goals": ["Improve GPA", "Avoid deadlines"]
  },
  "courses": [...],
  "tasks": [...],
  "grades": [...],
  "attendance": {...},
  "availability": {...},
  "productivity_pattern": {...},
  "historical_behavior": {...},
  "computed_analytics": {...}
}
```

See `data/sample_data.json` for a complete example.

## 🔧 Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DEEPSEEK_API_KEY` | DeepSeek API key | None (runs in mock mode) |
| `DEEPSEEK_API_BASE` | API base URL | `https://api.deepseek.com/v1` |
| `MODEL_NAME` | Model to use | `deepseek-reasoner` |
| `TIMEOUT` | Request timeout (seconds) | `60` |
| `TEMPERATURE` | LLM temperature (0-1) | `0.7` |
| `MAX_TOKENS` | Max response tokens | `4000` |

### Service Options

```python
service = UpGradeAIService(
    api_key="your_key",           # API key
    api_base_url="custom_url",    # Custom API endpoint
    model="deepseek-reasoner",    # Model name
    use_openai=False              # Use OpenAI-compatible API
)
```

## 📝 Output Files

After generating a study plan, you'll find:

### Study Plan Markdown (`output/study_plan_S-2026-XXX.md`)

Human-readable study plan with:
- Priority tasks for next 48 hours
- Weekly schedule optimization
- Strategic recommendations
- Risk alerts
- Study tips

### Full Response JSON (`output/response_S-2026-XXX.json`)

Complete API response including:
- Generated study plan
- Token usage statistics
- Raw API response
- Success/error status

## 🧪 Mock Mode (No API Key)

If no API key is provided, the service runs in **mock mode**:

```bash
# No .env file or empty DEEPSEEK_API_KEY
python ai_service.py
```

Mock mode:
- ✅ Generates realistic fake student data
- ✅ Returns example study plans
- ✅ Perfect for testing and development
- ❌ No actual LLM calls
- ❌ Always returns the same template plan

## 🔌 API Integration

### DeepSeek R1 API

The service uses DeepSeek's chat completion endpoint:

```python
POST https://api.deepseek.com/v1/chat/completions

Headers:
  Authorization: Bearer YOUR_API_KEY
  Content-Type: application/json

Body:
{
  "model": "deepseek-reasoner",
  "messages": [...],
  "temperature": 0.7,
  "max_tokens": 4000
}
```

### OpenAI Compatible

Also works with OpenAI or any OpenAI-compatible API:

```python
service = UpGradeAIService(
    api_key="sk-...",
    api_base_url="https://api.openai.com/v1",
    model="gpt-4",
    use_openai=True
)
```

## 🛠️ Development

### Run Tests

```bash
# Test data generator
python data/data_generator.py

# Test LLM client
python planner_llm/llm_client.py

# Test prompt formatting
python planner_llm/prompt.py
```

### Customize Prompts

Edit `planner_llm/prompt.py` to modify:
- System prompt (AI assistant personality)
- User prompt template (how data is formatted)
- Output structure

### Add New Data Fields

1. Update `data/data_generator.py` to generate new fields
2. Update `planner_llm/prompt.py` to include them in prompts
3. The LLM will automatically use the new information

## 📚 Dependencies

- `requests`: HTTP client for API calls
- `python-dotenv`: Environment variable management

## 🤝 Integration with Backend

To integrate with the main UpGrade backend:

```python
# In backend/app/services/planner_service.py
from ai.ai_service import UpGradeAIService

class PlannerService:
    def __init__(self):
        self.ai_service = UpGradeAIService(
            api_key=settings.DEEPSEEK_API_KEY
        )
    
    def generate_plan_for_user(self, user_id: str):
        # Fetch real user data from database
        student_data = self.get_user_data(user_id)
        
        # Generate plan
        result = self.ai_service.generate_study_plan(student_data)
        
        return result['study_plan']
```

## 🐛 Troubleshooting

### "No API key provided" Warning

**Solution**: Create `.env` file with `DEEPSEEK_API_KEY=your_key`

Or set environment variable:
```bash
export DEEPSEEK_API_KEY=your_key  # Linux/Mac
set DEEPSEEK_API_KEY=your_key     # Windows CMD
$env:DEEPSEEK_API_KEY="your_key"  # Windows PowerShell
```

### "Request timed out"

**Solution**: Increase timeout in `.env`:
```env
TIMEOUT=120
```

### Import Errors

**Solution**: Make sure you're in the `ai/` directory:
```bash
cd ai
python ai_service.py
```

## 📄 License

Part of the UpGrade platform.

---

**Generated by UpGrade AI Team** 🚀
