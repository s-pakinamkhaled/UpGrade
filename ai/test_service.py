"""
Quick Test Script for UpGrade AI Service
Run this to test the complete system
"""

import sys
from pathlib import Path

# Add parent directory to path
sys.path.append(str(Path(__file__).parent))

from ai_service import UpGradeAIService


def test_data_generation():
    """Test 1: Generate fake student data"""
    print("\n" + "="*60)
    print("TEST 1: Data Generation")
    print("="*60)
    
    service = UpGradeAIService()
    student_data = service.generate_fake_student_data()
    
    print(f"✅ Student: {student_data['student_profile']['name']}")
    print(f"✅ Courses: {len(student_data['courses'])}")
    print(f"✅ Tasks: {len(student_data['tasks'])}")
    print(f"✅ Grades: {len(student_data['grades'])}")
    
    return student_data


def test_study_plan_generation(student_data):
    """Test 2: Generate study plan"""
    print("\n" + "="*60)
    print("TEST 2: Study Plan Generation")
    print("="*60)
    
    service = UpGradeAIService()
    result = service.generate_study_plan(student_data, save_output=True)
    
    if result.get("success"):
        print("✅ Study plan generated successfully!")
        print(f"✅ Plan length: {len(result['study_plan'])} characters")
        return True
    else:
        print(f"❌ Failed: {result.get('error')}")
        return False


def test_with_sample_data():
    """Test 3: Use sample data file"""
    print("\n" + "="*60)
    print("TEST 3: Using Sample Data File")
    print("="*60)
    
    service = UpGradeAIService()
    
    try:
        student_data = service.load_student_data("data/sample_student.json")
        print(f"✅ Loaded: {student_data['student_profile']['name']}")
        
        result = service.generate_study_plan(student_data)
        
        if result.get("success"):
            print("✅ Study plan generated from sample data!")
            
            # Display preview
            plan = result['study_plan']
            preview = plan[:300] + "..." if len(plan) > 300 else plan
            print("\n📋 Preview:")
            print("-" * 60)
            print(preview)
            print("-" * 60)
            
            return True
        else:
            print(f"❌ Failed: {result.get('error')}")
            return False
            
    except FileNotFoundError:
        print("❌ Sample data file not found")
        return False


def main():
    """Run all tests"""
    print("\n" + "🚀 "*20)
    print("UpGrade AI Service - Test Suite")
    print("🚀 "*20)
    
    # Test 1: Generate data
    student_data = test_data_generation()
    
    # Test 2: Generate plan
    test_study_plan_generation(student_data)
    
    # Test 3: Use sample data
    test_with_sample_data()
    
    print("\n" + "="*60)
    print("✅ All tests completed!")
    print("="*60)
    print("\n📂 Check the 'output/' folder for generated study plans")
    print("📂 Check 'data/generated_student_data.json' for student data")
    
    print("\n💡 Tips:")
    print("  - Set DEEPSEEK_API_KEY in .env for real LLM calls")
    print("  - Without API key, it runs in MOCK MODE")
    print("  - Edit data/sample_student.json to test with custom data")
    print("  - Run 'python ai_service.py' for full demo")


if __name__ == "__main__":
    main()
