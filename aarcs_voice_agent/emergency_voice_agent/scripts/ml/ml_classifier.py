# ml_classifier.py - Machine Learning Emergency Classifier
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import pickle
import os
import json

class EmergencyClassifier:
    """ML-based emergency type classifier (better than keywords)"""
    
    def __init__(self):
        self.vectorizer = TfidfVectorizer(
            max_features=100,
            ngram_range=(1, 2),  # Use 1-word and 2-word phrases
            stop_words='english'
        )
        self.classifier = MultinomialNB()
        self.is_trained = False
        self.classes = ['accident', 'medical', 'fire', 'assault', 'other']
        
        # Try to load existing model
        if os.path.exists('models/classifier.pkl'):
            self.load_model()
            print("✅ Loaded existing ML model")
        else:
            print("⚠️ No trained model found. Train using train_model.py")
    
    def train(self, training_data):
        """
        Train the classifier
        training_data: list of (text, label) tuples
        """
        if len(training_data) < 10:
            print("⚠️ Warning: Very small training set!")
        
        texts = [item[0] for item in training_data]
        labels = [item[1] for item in training_data]
        
        # Split into train and test
        if len(training_data) > 20:
            X_train, X_test, y_train, y_test = train_test_split(
                texts, labels, test_size=0.2, random_state=42
            )
        else:
            X_train, y_train = texts, labels
            X_test, y_test = None, None
        
        # Train
        X_train_vec = self.vectorizer.fit_transform(X_train)
        self.classifier.fit(X_train_vec, y_train)
        self.is_trained = True
        
        # Evaluate
        train_accuracy = accuracy_score(y_train, self.classifier.predict(X_train_vec))
        print(f"✅ Training accuracy: {train_accuracy * 100:.1f}%")
        
        if X_test:
            X_test_vec = self.vectorizer.transform(X_test)
            test_predictions = self.classifier.predict(X_test_vec)
            test_accuracy = accuracy_score(y_test, test_predictions)
            print(f"✅ Test accuracy: {test_accuracy * 100:.1f}%")
        
        # Save model
        self.save_model()
    
    def predict(self, text):
        """
        Predict emergency type from text
        Returns: (predicted_class, confidence)
        """
        if not self.is_trained:
            print("⚠️ Model not trained! Using fallback 'other'")
            return 'other', 0.0
        
        # Transform text
        X = self.vectorizer.transform([text.lower()])
        
        # Predict
        prediction = self.classifier.predict(X)[0]
        
        # Get confidence (probability)
        probabilities = self.classifier.predict_proba(X)[0]
        confidence = max(probabilities)
        
        return prediction, confidence
    
    def save_model(self):
        """Save trained model to disk"""
        os.makedirs('models', exist_ok=True)
        with open('models/classifier.pkl', 'wb') as f:
            pickle.dump((self.vectorizer, self.classifier, self.classes), f)
        print("💾 Model saved to models/classifier.pkl")
    
    def load_model(self):
        """Load trained model from disk"""
        try:
            with open('models/classifier.pkl', 'rb') as f:
                self.vectorizer, self.classifier, self.classes = pickle.load(f)
            self.is_trained = True
            return True
        except Exception as e:
            print(f"❌ Error loading model: {e}")
            return False
