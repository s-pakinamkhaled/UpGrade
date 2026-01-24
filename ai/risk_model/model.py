"""
ML model for risk prediction.
"""
from typing import List, Dict, Any
import pickle
import os

class RiskModel:
    """Risk prediction model."""
    
    def __init__(self, model_path: str = None):
        self.model = None
        self.model_path = model_path or "models/risk_model.pkl"
        self._load_model()
    
    def _load_model(self):
        """Load the trained model."""
        if os.path.exists(self.model_path):
            with open(self.model_path, 'rb') as f:
                self.model = pickle.load(f)
        else:
            # Use rule-based fallback if model not found
            self.model = None
    
    def predict(self, features: List[float]) -> float:
        """
        Predict risk score from features.
        
        Args:
            features: List of feature values
        
        Returns:
            Risk score between 0.0 and 1.0
        """
        if self.model is None:
            # Fallback to simple heuristic
            return min(sum(features[:3]) / 10.0, 1.0)
        
        try:
            prediction = self.model.predict([features])[0]
            return float(prediction)
        except Exception:
            return 0.5  # Default risk
    
    def predict_batch(self, tasks: List[Dict[str, Any]]) -> Dict[int, float]:
        """
        Predict risk scores for multiple tasks.
        
        Args:
            tasks: List of task dictionaries
        
        Returns:
            Dictionary mapping task_id to risk_score
        """
        from .features import extract_features
        
        results = {}
        for task in tasks:
            features = extract_features(task)
            risk_score = self.predict(features)
            results[task["id"]] = risk_score
        
        return results

