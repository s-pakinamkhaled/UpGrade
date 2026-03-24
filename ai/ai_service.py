"""
UpGrade AI Service
Main service that coordinates data generation and LLM-based study plan generation
"""

import os
import json
from typing import Dict, Any, Optional
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Import our modules
from data.data_generator import StudentDataGenerator
from planner_llm.llm_client import DeepSeekLLMClient, OpenAICompatibleClient, GroqClient
from planner_llm.prompt import StudyPlanPrompts


class UpGradeAIService:
    """Main AI service for generating personalized study plans"""
    
    def __init__(
        self,
        api_key: Optional[str] = None,
        api_base_url: Optional[str] = None,
        model: Optional[str] = None,
        provider: Optional[str] = None
    ):
        """
        Initialize UpGrade AI Service
        
        Args:
            api_key: API key for LLM service
            api_base_url: Base URL for API
            model: Model name to use
            provider: LLM provider ('groq', 'deepseek', 'openai') - defaults to env var LLM_PROVIDER
        """
        # Determine provider from env or parameter
        provider = provider or os.getenv("LLM_PROVIDER", "groq")
        
        print(f"🤖 Initializing with provider: {provider}")
        
        if provider.lower() == "groq":
            self.llm_client = GroqClient(
                api_key=api_key or os.getenv("GROQ_API_KEY"),
                model=model or os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")
            )
        elif provider.lower() == "openai":
            self.llm_client = OpenAICompatibleClient(
                api_key=api_key or os.getenv("OPENAI_API_KEY"),
                api_base_url=api_base_url or os.getenv("OPENAI_API_BASE", "https://api.openai.com/v1"),
                model=model or os.getenv("OPENAI_MODEL", "gpt-4")
            )
        else:  # deepseek
            self.llm_client = DeepSeekLLMClient(
                api_key=api_key or os.getenv("DEEPSEEK_API_KEY"),
                api_base_url=api_base_url or os.getenv("DEEPSEEK_API_BASE"),
                model=model or os.getenv("DEEPSEEK_MODEL", "deepseek-reasoner")
            )
        
        self.data_generator = StudentDataGenerator()
        self.prompt_builder = StudyPlanPrompts()
    
    def generate_fake_student_data(self) -> Dict[str, Any]:
        """
        Generate fake student data
        
        Returns:
            Complete student data dictionary
        """
        print("📊 Generating fake student data...")
        return self.data_generator.generate_complete_student_data()
    
    def load_student_data(self, file_path: str) -> Dict[str, Any]:
        """
        Load student data from JSON file
        
        Args:
            file_path: Path to JSON file
            
        Returns:
            Student data dictionary
        """
        print(f"📂 Loading student data from {file_path}...")
        
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    
    def save_student_data(self, student_data: Dict[str, Any], file_path: str) -> None:
        """
        Save student data to JSON file
        
        Args:
            student_data: Student data dictionary
            file_path: Path to save file
        """
        # Create directory if it doesn't exist
        Path(file_path).parent.mkdir(parents=True, exist_ok=True)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(student_data, f, indent=2, ensure_ascii=False)
        
        print(f"💾 Student data saved to {file_path}")
    
    def generate_study_plan(
        self,
        student_data: Dict[str, Any],
        save_output: bool = True,
        output_dir: str = "output"
    ) -> Dict[str, Any]:
        """
        Generate personalized study plan using LLM
        
        Args:
            student_data: Complete student data dictionary
            save_output: Whether to save the output
            output_dir: Directory to save output files
            
        Returns:
            Study plan response
        """
        print("\n" + "="*60)
        print("🎓 UpGrade AI Study Plan Generator")
        print("="*60)
        
        # Build prompts
        system_prompt = self.prompt_builder.get_system_prompt()
        user_prompt = self.prompt_builder.format_student_data_prompt(student_data)
        
        # Generate study plan using LLM
        result = self.llm_client.generate_study_plan(
            student_data=student_data,
            system_prompt=system_prompt,
            user_prompt=user_prompt
        )
        
        if result.get("success"):
            print("✅ Study plan generated successfully!")
            
            if save_output:
                # Save output
                Path(output_dir).mkdir(parents=True, exist_ok=True)
                
                student_name = student_data['student_profile']['name'].replace(' ', '_')
                student_id = student_data['student_profile']['student_id']
                
                # Save study plan as markdown
                plan_file = f"{output_dir}/study_plan_{student_id}.md"
                with open(plan_file, 'w', encoding='utf-8') as f:
                    f.write(f"# Study Plan for {student_data['student_profile']['name']}\n\n")
                    f.write(f"**Generated**: {Path(plan_file).stat().st_mtime}\n\n")
                    f.write(result['study_plan'])
                
                print(f"📄 Study plan saved to: {plan_file}")
                
                # Save full response as JSON
                response_file = f"{output_dir}/response_{student_id}.json"
                with open(response_file, 'w', encoding='utf-8') as f:
                    json.dump(result, f, indent=2, ensure_ascii=False)
                
                print(f"📋 Full response saved to: {response_file}")
        else:
            print(f"❌ Failed to generate study plan: {result.get('error', 'Unknown error')}")
        
        return result
    
    def run_demo(
        self,
        use_existing_data: bool = False,
        data_file: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Run a complete demo: generate data + create study plan
        
        Args:
            use_existing_data: Whether to use existing data file
            data_file: Path to existing data file (if use_existing_data=True)
            
        Returns:
            Study plan result
        """
        print("\n" + "🚀 "* 20)
        print("Starting UpGrade AI Demo")
        print("🚀 "*20 + "\n")
        
        # Step 1: Get student data
        if use_existing_data and data_file:
            student_data = self.load_student_data(data_file)
        else:
            student_data = self.generate_fake_student_data()
            self.save_student_data(student_data, "data/generated_student_data.json")
        
        print(f"\n📊 Student: {student_data['student_profile']['name']}")
        print(f"📚 Courses: {len(student_data['courses'])}")
        print(f"📝 Tasks: {len(student_data['tasks'])}")
        print(f"⚠️  High Priority Tasks: {sum(1 for t in student_data['tasks'] if t['priority'] == 'high')}")
        
        # Step 2: Generate study plan
        result = self.generate_study_plan(student_data)
        
        # Step 3: Display summary
        if result.get("success"):
            print("\n" + "="*60)
            print("📋 STUDY PLAN PREVIEW")
            print("="*60)
            plan = result['study_plan']
            # Show first 500 characters
            preview = plan[:500] + "..." if len(plan) > 500 else plan
            print(preview)
            print("\n" + "="*60)
            
            if "usage" in result:
                usage = result["usage"]
                print(f"📊 Tokens used: {usage.get('total_tokens', 'N/A')}")
        
        print("\n✨ Demo completed!")
        return result


def main():
    """Main entry point"""
    # Configuration
    API_KEY = os.getenv("DEEPSEEK_API_KEY")
    
    # Initialize service
    service = UpGradeAIService(
        api_key=API_KEY,
        model="deepseek-reasoner"
    )
    
    # Run demo
    result = service.run_demo(
        use_existing_data=False  # Set to True to use existing data
    )
    
    return result


if __name__ == "__main__":
    main()
