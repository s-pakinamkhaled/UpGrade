"""
Prompt Templates for Study Plan Generation
Contains system prompts and user prompt templates for LLM interaction
"""

import json
from typing import Dict, Any
from datetime import datetime


class StudyPlanPrompts:
    """Prompt templates for generating personalized study plans"""
    
    SYSTEM_PROMPT = """You are an expert AI study planning assistant for the UpGrade platform.

Your role is to analyze comprehensive student data and generate highly personalized, actionable study plans that help students:
- Prioritize tasks based on urgency, difficulty, and importance
- Optimize their study schedule around their availability and productivity patterns
- Reduce stress and prevent burnout
- Improve academic performance
- Meet all deadlines effectively

You will receive detailed student data including:
- Profile and goals
- Current courses and difficulty levels
- Pending tasks with deadlines and progress
- Past grades and performance
- Attendance records
- Available study time slots
- Productivity patterns and preferences
- Historical behavior (missed deadlines, late submissions)
- Computed risk analytics per course

Your study plans should:
1. Be specific and actionable with exact time slots
2. Consider the student's peak productivity hours
3. Prioritize high-risk tasks and courses
4. Break down large tasks into manageable chunks
5. Include strategic recommendations for improvement
6. Provide motivational and practical study tips
7. Account for workload forecasts and prevent overload
8. Use the student's actual availability schedule

Output Format:
- Use clear Markdown formatting with headers and sections
- Include emojis for better readability
- Organize by priority levels (High/Medium/Low)
- Provide daily and weekly views
- Give specific time allocations
- Highlight risk areas and provide mitigation strategies

Be encouraging, practical, and data-driven in your recommendations."""

    @staticmethod
    def format_student_data_prompt(student_data: Dict[str, Any]) -> str:
        """
        Format student data into a comprehensive prompt for the LLM
        
        Args:
            student_data: Complete student data dictionary
            
        Returns:
            Formatted prompt string
        """
        profile = student_data["student_profile"]
        courses = student_data["courses"]
        tasks = student_data["tasks"]
        grades = student_data["grades"]
        attendance = student_data["attendance"]
        availability = student_data["availability"]
        productivity = student_data["productivity_pattern"]
        historical = student_data["historical_behavior"]
        analytics = student_data["computed_analytics"]
        
        # Format tasks with priority
        high_priority_tasks = [t for t in tasks if t["priority"] == "high"]
        medium_priority_tasks = [t for t in tasks if t["priority"] == "medium"]
        low_priority_tasks = [t for t in tasks if t["priority"] == "low"]
        
        # Calculate days until deadlines
        today = datetime.now()
        for task in tasks:
            deadline = datetime.strptime(task["deadline"], "%Y-%m-%d")
            days_left = (deadline - today).days
            task["days_until_deadline"] = days_left
        
        prompt = f"""# Student Analysis Request

## 👤 Student Profile
- **Name**: {profile['name']}
- **ID**: {profile['student_id']}
- **University**: {profile['university']}
- **Major**: {profile['major']}
- **Academic Year**: {profile['academic_year']}
- **Semester**: {profile['semester']}
- **Goals**: {', '.join(profile['goals'])}

## 📚 Enrolled Courses ({len(courses)} courses)
"""
        
        for course in courses:
            course_risk = next(
                (r for r in analytics["risk_per_course"] if r["course_id"] == course["course_id"]),
                None
            )
            risk_info = f" | ⚠️ Risk: {course_risk['risk_level'].upper()} ({course_risk['risk_score']}/100)" if course_risk else ""
            attendance_pct = attendance.get(course["course_id"], "N/A")
            
            prompt += f"""
### {course['course_name']} ({course['course_id']})
- Instructor: {course['instructor']}
- Credits: {course['credit_hours']} | Difficulty: {course['difficulty_level']}/5 | Importance: {course['importance_weight']}
- Attendance: {attendance_pct}%{risk_info}
"""
        
        prompt += f"""

## 📝 Pending Tasks ({len(tasks)} tasks)

### 🔴 HIGH PRIORITY ({len(high_priority_tasks)} tasks)
"""
        
        for task in high_priority_tasks:
            prompt += f"""
**{task['task_title']}**
- Course: {task['course_name']}
- Type: {task['task_type']}
- Deadline: {task['deadline']} ({task['days_until_deadline']} days left)
- Estimated Time: {task['estimated_duration_minutes']} minutes ({task['estimated_duration_minutes']//60}h {task['estimated_duration_minutes']%60}m)
- Progress: {task['current_progress_percentage']}%
"""
        
        if medium_priority_tasks:
            prompt += f"""
### 🟡 MEDIUM PRIORITY ({len(medium_priority_tasks)} tasks)
"""
            for task in medium_priority_tasks:
                prompt += f"""
**{task['task_title']}**
- Deadline: {task['deadline']} ({task['days_until_deadline']} days)
- Time needed: {task['estimated_duration_minutes']//60}h {task['estimated_duration_minutes']%60}m
- Progress: {task['current_progress_percentage']}%
"""
        
        if low_priority_tasks:
            prompt += f"""
### 🟢 LOW PRIORITY ({len(low_priority_tasks)} tasks)
"""
            for task in low_priority_tasks:
                prompt += f"- {task['task_title']} (Due: {task['deadline']})\n"
        
        prompt += f"""

## 📊 Past Performance

### Recent Grades
"""
        
        for grade in grades[:5]:  # Show last 5 grades
            percentage = (grade['score'] / grade['max_score']) * 100
            prompt += f"- {grade['course_id']} - {grade['assessment_name']}: {grade['score']}/{grade['max_score']} ({percentage:.0f}%) - Weight: {grade['weight_percentage']}%\n"
        
        prompt += f"""

## ⏰ Available Study Time

### Weekly Schedule
"""
        
        for day, slots in availability["weekly_schedule"].items():
            if slots:
                time_slots = ", ".join([f"{slot['start']}-{slot['end']}" for slot in slots])
                prompt += f"- **{day}**: {time_slots}\n"
            else:
                prompt += f"- **{day}**: Not available\n"
        
        prompt += f"""
- **Max Daily Study Hours**: {availability['max_daily_study_hours']} hours

## 📈 Productivity Patterns
- **Preferred Study Days**: {', '.join(productivity['preferred_study_days'])}
- **Peak Focus Hours**: {', '.join(productivity['peak_focus_hours'])}
- **Average Focus Session**: {productivity['average_focus_session_minutes']} minutes
- **Average Break**: {productivity['average_break_minutes']} minutes
- **Last Week Study Time**: {productivity['total_study_hours_last_week']} hours
- **Productivity Score**: {productivity['productivity_score']}/100

## 📉 Historical Behavior
- **Missed Deadlines**: {historical['missed_deadlines_count']} tasks
- **Late Submission Rate**: {historical['late_submission_rate']*100:.0f}%
- **Avg Daily Study Time**: {historical['average_daily_study_minutes']} minutes
- **Most Delayed Course**: {historical['most_delayed_course']}

## ⚠️ Risk Analytics

### Course-Level Risks
"""
        
        for risk in analytics["risk_per_course"]:
            emoji = "🔴" if risk["risk_level"] == "high" else "🟡" if risk["risk_level"] == "medium" else "🟢"
            prompt += f"""
{emoji} **{risk['course_id']}** - {risk['risk_level'].upper()} ({risk['risk_score']}/100)
- Reason: {risk['reason']}
"""
        
        workload = analytics["workload_forecast"]
        overload_warning = " ⚠️ OVERLOAD RISK!" if workload["overload_risk"] else ""
        
        prompt += f"""
### Workload Forecast
- **Current Week**: {workload['current_week_load_hours']} hours
- **Next Week**: {workload['next_week_load_hours']} hours{overload_warning}

---

## 🎯 Your Task

Based on this comprehensive student data, create a personalized, actionable study plan that:

1. **Prioritizes urgent and high-risk tasks** for the next 48-72 hours
2. **Creates a detailed weekly schedule** matching the student's availability
3. **Optimizes for peak productivity hours** and respects break patterns
4. **Provides specific time allocations** for each task
5. **Addresses high-risk courses** with targeted interventions
6. **Prevents workload overload** with realistic scheduling
7. **Includes study tips and strategies** tailored to the student's needs
8. **Motivates the student** while being practical and achievable

Generate a complete study plan now."""

        return prompt
    
    @staticmethod
    def format_quick_question_prompt(question: str, student_data: Dict[str, Any]) -> str:
        """
        Format a quick question about study planning
        
        Args:
            question: User's question
            student_data: Student data for context
            
        Returns:
            Formatted prompt
        """
        profile = student_data["student_profile"]
        
        prompt = f"""Student {profile['name']} (Year {profile['academic_year']}, {profile['major']}) asks:

"{question}"

Current situation:
- {len(student_data['tasks'])} pending tasks
- {len(student_data['courses'])} enrolled courses
- Goals: {', '.join(profile['goals'])}

Provide a helpful, specific answer based on their data."""

        return prompt
    
    @staticmethod
    def get_system_prompt() -> str:
        """Get the system prompt"""
        return StudyPlanPrompts.SYSTEM_PROMPT


def test_prompt_formatting():
    """Test prompt formatting with sample data"""
    sample_data = {
        "student_profile": {
            "student_id": "S-2026-001",
            "name": "Ahmed Hassan",
            "email": "ahmed@student.edu",
            "university": "Faculty of Science",
            "major": "AI Engineering",
            "academic_year": 3,
            "semester": "Spring 2026",
            "goals": ["Improve GPA", "Avoid missing deadlines"]
        },
        "courses": [
            {
                "course_id": "AI401",
                "course_name": "Artificial Intelligence",
                "instructor": "Dr. Mohamed",
                "credit_hours": 3,
                "difficulty_level": 5,
                "importance_weight": 0.9
            }
        ],
        "tasks": [
            {
                "task_id": "T-AI-01",
                "course_id": "AI401",
                "course_name": "Artificial Intelligence",
                "task_title": "Assignment 2",
                "task_type": "assignment",
                "deadline": "2026-02-05",
                "estimated_duration_minutes": 240,
                "current_progress_percentage": 20,
                "priority": "high",
                "is_completed": False
            }
        ],
        "grades": [],
        "attendance": {"AI401": 85},
        "availability": {
            "weekly_schedule": {
                "Saturday": [{"start": "18:00", "end": "22:00"}]
            },
            "max_daily_study_hours": 4
        },
        "productivity_pattern": {
            "preferred_study_days": ["Saturday"],
            "peak_focus_hours": ["18:00-22:00"],
            "average_focus_session_minutes": 50,
            "average_break_minutes": 10,
            "total_study_hours_last_week": 10,
            "productivity_score": 72
        },
        "historical_behavior": {
            "missed_deadlines_count": 2,
            "late_submission_rate": 0.25,
            "average_daily_study_minutes": 90,
            "most_delayed_course": "AI"
        },
        "computed_analytics": {
            "risk_per_course": [
                {
                    "course_id": "AI401",
                    "risk_score": 78,
                    "risk_level": "high",
                    "reason": "Close deadline"
                }
            ],
            "workload_forecast": {
                "current_week_load_hours": 8,
                "next_week_load_hours": 14,
                "overload_risk": True
            }
        }
    }
    
    prompt = StudyPlanPrompts.format_student_data_prompt(sample_data)
    print(prompt)


if __name__ == "__main__":
    test_prompt_formatting()
