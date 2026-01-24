# API Specification

## Base URL
`http://localhost:8000`

## Authentication
All protected endpoints require a JWT token in the Authorization header:
```
Authorization: Bearer <token>
```

## Endpoints

### Auth

#### POST /auth/register
Register a new user.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "full_name": "John Doe"
}
```

**Response:**
```json
{
  "id": 1,
  "email": "user@example.com",
  "full_name": "John Doe",
  "is_active": true,
  "created_at": "2024-01-01T00:00:00"
}
```

#### POST /auth/login
Login and get access token.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "access_token": "eyJ...",
  "token_type": "bearer"
}
```

### Tasks

#### GET /tasks/
Get all tasks for the current user.

**Response:**
```json
[
  {
    "id": 1,
    "title": "Math Assignment",
    "description": "Complete chapter 5",
    "due_date": "2024-01-15T23:59:59",
    "priority": 8,
    "status": "pending",
    "risk_score": 0.7
  }
]
```

#### POST /tasks/
Create a new task.

**Request Body:**
```json
{
  "title": "Math Assignment",
  "description": "Complete chapter 5",
  "due_date": "2024-01-15T23:59:59",
  "priority": 8,
  "estimated_hours": 5.0
}
```

#### PUT /tasks/{task_id}
Update a task.

#### DELETE /tasks/{task_id}
Delete a task.

### Planner

#### GET /planner/
Get all study plans.

#### POST /planner/
Create a new study plan.

**Request Body:**
```json
{
  "name": "January Study Plan",
  "start_date": "2024-01-01T00:00:00",
  "end_date": "2024-01-31T23:59:59"
}
```

### Classroom

#### GET /classroom/courses
Get all synced courses.

#### POST /classroom/sync
Sync courses from external classroom system.

