# Upgrade - Study Planning Application

A comprehensive study planning application with AI-powered risk assessment and scheduling.

## Project Structure

```
upgrade/
├── backend/          # FastAPI backend
├── ai/               # AI services (risk model, LLM planner)
├── frontend/         # Flutter mobile app
├── testing/          # Test suites
└── docs/             # Documentation
```

## Getting Started

### Prerequisites

- Python 3.11+
- Flutter 3.0+
- Docker (optional)

### Backend Setup

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### AI Service Setup

```bash
cd ai
pip install -r requirements.txt
uvicorn ai_service:app --reload
```

### Frontend Setup

```bash
cd frontend
flutter pub get
flutter run
```

### Docker Setup

```bash
docker-compose up
```

## Features

- Task management
- AI-powered risk assessment
- LLM-based study planning
- Classroom integration
- Real-time notifications

## API Documentation

See `docs/api_spec.md` for detailed API documentation.

## License

MIT

