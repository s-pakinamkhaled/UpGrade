"""
Fake Student Data Generator
Generates realistic student profiles with courses, tasks, grades, and analytics
"""

import json
import random
from datetime import datetime, timedelta
from typing import Dict, List, Any


class StudentDataGenerator:
    """Generate fake student data for testing and demonstration"""
    
    STUDENT_NAMES = [
        "Ahmed Hassan", "Sarah Mohamed", "Omar Ali", "Fatima Ibrahim",
        "Youssef Mahmoud", "Nour Ahmed", "Karim Said", "Layla Hussain"
    ]
    
    UNIVERSITIES = [
        "Faculty of Science", "Faculty of Engineering", "Faculty of Computer Science",
        "Faculty of Medicine", "Faculty of Business"
    ]
    
    MAJORS = [
        "AI Engineering", "Computer Science", "Data Science", "Software Engineering",
        "Information Systems", "Cybersecurity"
    ]
    
    COURSES = [
        {"name": "Artificial Intelligence", "code": "AI401", "difficulty": 5, "credits": 3},
        {"name": "Data Mining", "code": "DS312", "difficulty": 4, "credits": 3},
        {"name": "Machine Learning", "code": "ML501", "difficulty": 5, "credits": 4},
        {"name": "Database Systems", "code": "DB301", "difficulty": 3, "credits": 3},
        {"name": "Web Development", "code": "WEB201", "difficulty": 2, "credits": 3},
        {"name": "Algorithms", "code": "ALG301", "difficulty": 4, "credits": 4},
        {"name": "Computer Networks", "code": "NET401", "difficulty": 3, "credits": 3},
        {"name": "Software Engineering", "code": "SE302", "difficulty": 3, "credits": 3},
    ]
    
    TASK_TYPES = ["assignment", "quiz", "project", "exam", "homework"]
    
    DAYS_OF_WEEK = ["Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    
    @staticmethod
    def generate_student_profile() -> Dict[str, Any]:
        """Generate a random student profile"""
        student_id = f"S-2026-{random.randint(100, 999):03d}"
        name = random.choice(StudentDataGenerator.STUDENT_NAMES)
        email = f"{name.lower().replace(' ', '.')}@student.edu"
        
        return {
            "student_id": student_id,
            "name": name,
            "email": email,
            "university": random.choice(StudentDataGenerator.UNIVERSITIES),
            "major": random.choice(StudentDataGenerator.MAJORS),
            "academic_year": random.randint(2, 4),
            "semester": "Spring 2026",
            "timezone": "Africa/Cairo",
            "goals": random.sample([
                "Improve GPA",
                "Avoid missing deadlines",
                "Reduce study stress",
                "Master programming skills",
                "Prepare for exams",
                "Balance work and life"
            ], k=3)
        }
    
    @staticmethod
    def generate_courses(num_courses: int = 4) -> List[Dict[str, Any]]:
        """Generate random course enrollments"""
        selected_courses = random.sample(StudentDataGenerator.COURSES, min(num_courses, len(StudentDataGenerator.COURSES)))
        
        courses = []
        for course in selected_courses:
            courses.append({
                "course_id": course["code"],
                "course_name": course["name"],
                "instructor": f"Dr. {random.choice(['Mohamed Ali', 'Sara Ahmed', 'Ahmed Hassan', 'Fatima Said'])}",
                "credit_hours": course["credits"],
                "difficulty_level": course["difficulty"],
                "importance_weight": round(random.uniform(0.6, 0.95), 2)
            })
        
        return courses
    
    @staticmethod
    def generate_tasks(courses: List[Dict[str, Any]], num_tasks: int = 5) -> List[Dict[str, Any]]:
        """Generate random tasks/assignments"""
        tasks = []
        today = datetime.now()
        
        for i in range(num_tasks):
            course = random.choice(courses)
            task_type = random.choice(StudentDataGenerator.TASK_TYPES)
            
            # Deadlines within next 14 days
            deadline_days = random.randint(1, 14)
            deadline = today + timedelta(days=deadline_days)
            
            # Priority based on deadline and difficulty
            if deadline_days <= 2:
                priority = "high"
            elif deadline_days <= 7:
                priority = "medium"
            else:
                priority = "low"
            
            tasks.append({
                "task_id": f"T-{course['course_id']}-{i+1:02d}",
                "course_id": course["course_id"],
                "course_name": course["course_name"],
                "task_title": f"{task_type.capitalize()} {i+1} – {course['course_name']}",
                "task_type": task_type,
                "deadline": deadline.strftime("%Y-%m-%d"),
                "estimated_duration_minutes": random.choice([60, 90, 120, 180, 240]),
                "current_progress_percentage": random.randint(0, 70),
                "priority": priority,
                "is_completed": False
            })
        
        # Sort by deadline
        tasks.sort(key=lambda x: x["deadline"])
        
        return tasks
    
    @staticmethod
    def generate_grades(courses: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Generate random grades for courses"""
        grades = []
        
        for course in courses:
            num_assessments = random.randint(1, 3)
            
            for i in range(num_assessments):
                assessment_type = random.choice(["midterm", "quiz", "assignment", "project"])
                max_score = random.choice([10, 20, 30, 50, 100])
                score = random.randint(int(max_score * 0.5), max_score)
                
                past_date = datetime.now() - timedelta(days=random.randint(5, 30))
                
                grades.append({
                    "course_id": course["course_id"],
                    "assessment_type": assessment_type,
                    "assessment_name": f"{assessment_type.capitalize()} {i+1}",
                    "score": score,
                    "max_score": max_score,
                    "date": past_date.strftime("%Y-%m-%d"),
                    "weight_percentage": random.choice([10, 15, 20, 30])
                })
        
        return grades
    
    @staticmethod
    def generate_attendance(courses: List[Dict[str, Any]]) -> Dict[str, int]:
        """Generate random attendance percentages"""
        return {
            course["course_id"]: random.randint(60, 95)
            for course in courses
        }
    
    @staticmethod
    def generate_availability() -> Dict[str, Any]:
        """Generate student's available study times"""
        weekly_schedule = {}
        
        for day in StudentDataGenerator.DAYS_OF_WEEK:
            if day == "Friday" or random.random() < 0.2:  # 20% chance of no availability
                weekly_schedule[day] = []
            else:
                # Random study slots
                num_slots = random.randint(1, 2)
                slots = []
                
                for _ in range(num_slots):
                    start_hour = random.randint(14, 19)
                    end_hour = start_hour + random.randint(2, 5)
                    
                    slots.append({
                        "start": f"{start_hour:02d}:00",
                        "end": f"{min(end_hour, 23):02d}:00"
                    })
                
                weekly_schedule[day] = slots
        
        return {
            "weekly_schedule": weekly_schedule,
            "max_daily_study_hours": random.choice([3, 4, 5, 6])
        }
    
    @staticmethod
    def generate_productivity_pattern(availability: Dict[str, Any]) -> Dict[str, Any]:
        """Generate productivity patterns"""
        study_days = [day for day, slots in availability["weekly_schedule"].items() if slots]
        
        return {
            "preferred_study_days": study_days,
            "peak_focus_hours": ["18:00-22:00"],
            "average_focus_session_minutes": random.choice([30, 45, 50, 60]),
            "average_break_minutes": random.choice([5, 10, 15]),
            "total_study_hours_last_week": random.randint(8, 20),
            "productivity_score": random.randint(60, 90)
        }
    
    @staticmethod
    def generate_historical_behavior() -> Dict[str, Any]:
        """Generate historical behavior data"""
        return {
            "missed_deadlines_count": random.randint(0, 5),
            "late_submission_rate": round(random.uniform(0.0, 0.4), 2),
            "average_daily_study_minutes": random.randint(60, 180),
            "most_delayed_course": random.choice(["Artificial Intelligence", "Machine Learning", "Data Mining"])
        }
    
    @staticmethod
    def generate_computed_analytics(courses: List[Dict[str, Any]], tasks: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Generate risk analytics and workload forecasts"""
        risk_per_course = []
        
        for course in courses:
            risk_score = random.randint(30, 85)
            
            if risk_score >= 70:
                risk_level = "high"
                reason = "High difficulty + low progress + close deadline"
            elif risk_score >= 50:
                risk_level = "medium"
                reason = "Moderate performance and upcoming assessments"
            else:
                risk_level = "low"
                reason = "Good progress and manageable workload"
            
            risk_per_course.append({
                "course_id": course["course_id"],
                "risk_score": risk_score,
                "risk_level": risk_level,
                "reason": reason
            })
        
        current_week_load = sum(
            task["estimated_duration_minutes"] for task in tasks[:3]
        ) // 60
        
        next_week_load = sum(
            task["estimated_duration_minutes"] for task in tasks[3:]
        ) // 60
        
        return {
            "risk_per_course": risk_per_course,
            "workload_forecast": {
                "current_week_load_hours": current_week_load,
                "next_week_load_hours": next_week_load,
                "overload_risk": current_week_load + next_week_load > 20
            }
        }
    
    @classmethod
    def generate_complete_student_data(cls) -> Dict[str, Any]:
        """Generate complete fake student data"""
        student_profile = cls.generate_student_profile()
        courses = cls.generate_courses(num_courses=random.randint(3, 5))
        tasks = cls.generate_tasks(courses, num_tasks=random.randint(4, 8))
        grades = cls.generate_grades(courses)
        attendance = cls.generate_attendance(courses)
        availability = cls.generate_availability()
        productivity_pattern = cls.generate_productivity_pattern(availability)
        historical_behavior = cls.generate_historical_behavior()
        computed_analytics = cls.generate_computed_analytics(courses, tasks)
        
        return {
            "student_profile": student_profile,
            "courses": courses,
            "tasks": tasks,
            "grades": grades,
            "attendance": attendance,
            "availability": availability,
            "productivity_pattern": productivity_pattern,
            "historical_behavior": historical_behavior,
            "computed_analytics": computed_analytics
        }


def main():
    """Generate and save sample student data"""
    generator = StudentDataGenerator()
    student_data = generator.generate_complete_student_data()
    
    # Save to file
    output_path = "data/generated_student_data.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(student_data, f, indent=2, ensure_ascii=False)
    
    print(f"✅ Generated student data saved to: {output_path}")
    print(f"📊 Student: {student_data['student_profile']['name']}")
    print(f"📚 Courses: {len(student_data['courses'])}")
    print(f"📝 Tasks: {len(student_data['tasks'])}")


if __name__ == "__main__":
    main()
