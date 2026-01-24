"""
Training script for risk model.
"""
import json
import pickle
from typing import List, Dict, Any
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from .features import extract_features

def load_training_data(data_path: str) -> tuple[List[List[float]], List[float]]:
    """
    Load and prepare training data.
    
    Args:
        data_path: Path to training data JSON file
    
    Returns:
        Tuple of (features, labels)
    """
    with open(data_path, 'r') as f:
        data = json.load(f)
    
    features = []
    labels = []
    
    for item in data:
        task_features = extract_features(item["task"])
        features.append(task_features)
        labels.append(item["risk_score"])
    
    return features, labels

def train_model(data_path: str, output_path: str = "models/risk_model.pkl"):
    """
    Train the risk prediction model.
    
    Args:
        data_path: Path to training data
        output_path: Path to save trained model
    """
    # Load data
    X, y = load_training_data(data_path)
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Train model
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    
    # Evaluate
    score = model.score(X_test, y_test)
    print(f"Model accuracy: {score:.2f}")
    
    # Save model
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'wb') as f:
        pickle.dump(model, f)
    
    print(f"Model saved to {output_path}")

if __name__ == "__main__":
    import os
    os.makedirs("models", exist_ok=True)
    train_model("data/training_data.json")

