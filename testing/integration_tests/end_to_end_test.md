# End-to-End Test Plan

## Test Scenarios

### 1. User Registration and Login
- Register a new user
- Login with credentials
- Verify JWT token is received

### 2. Task Management
- Create a new task
- Retrieve all tasks
- Update a task
- Delete a task
- Verify task risk scores are calculated

### 3. Study Plan Creation
- Create a study plan
- Generate schedule using AI
- View schedule
- Update study plan

### 4. Classroom Integration
- Sync courses from external system
- View synced courses
- Verify tasks are linked to courses

### 5. Risk Assessment
- Verify risk scores are calculated for tasks
- Check high-risk alerts are sent
- Verify risk scores update over time

## Test Data

### Sample User
- Email: test@example.com
- Password: testpassword123

### Sample Tasks
- Math Assignment (due in 3 days, 5 hours)
- History Exam (due in 7 days, 10 hours)
- Essay (due in 5 days, 8 hours)

## Expected Results

All API endpoints should return appropriate status codes:
- 200 for successful GET requests
- 201 for successful POST requests
- 200 for successful PUT/DELETE requests
- 401 for unauthorized requests
- 404 for not found resources

