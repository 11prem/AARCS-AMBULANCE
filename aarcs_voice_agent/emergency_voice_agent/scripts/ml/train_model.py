# train_model.py - Train the ML classifier
from ml_classifier import EmergencyClassifier
import json
import os

def load_training_data():
    """Load training data from JSON file"""
    try:
        with open('data/training_data.json', 'r') as f:
            data = json.load(f)
        return data['training_samples']
    except FileNotFoundError:
        print("❌ training_data.json not found in data/ folder!")
        return []
    except Exception as e:
        print(f"❌ Error loading training data: {e}")
        return []

def main():
    print("=" * 60)
    print("🎓 Training Emergency Classification Model")
    print("=" * 60)
    
    # Create models directory
    os.makedirs('models', exist_ok=True)
    
    # Load training data
    training_data = load_training_data()
    
    if not training_data:
        print("❌ No training data available!")
        return
    
    print(f"\n📚 Loaded {len(training_data)} training samples")
    
    # Initialize and train classifier
    classifier = EmergencyClassifier()
    classifier.train(training_data)
    
    print("\n" + "=" * 60)
    print("✅ Training Complete!")
    print("=" * 60)
    
    # Test with examples
    print("\n🧪 Testing trained model:")
    test_cases = [
        "there has been a car crash",
        "my mother is having chest pain",
        "the building is on fire",
        "someone attacked me with a knife",
        "need medical help urgently"
    ]
    
    for test in test_cases:
        prediction, confidence = classifier.predict(test)
        print(f"\n  '{test}'")
        print(f"  → {prediction.upper()} (confidence: {confidence:.2%})")

if __name__ == "__main__":
    main()
