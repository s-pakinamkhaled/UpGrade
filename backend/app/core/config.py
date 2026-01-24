"""
Environment variables and configuration.
"""
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # Database
    database_url: str = "sqlite:///./upgrade.db"
    
    # JWT
    secret_key: str = "your-secret-key-here"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    
    # AI Service
    ai_service_url: Optional[str] = None
    
    # Classroom Integration
    classroom_api_key: Optional[str] = None
    
    class Config:
        env_file = ".env"

settings = Settings()

