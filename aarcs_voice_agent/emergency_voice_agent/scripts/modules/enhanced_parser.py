# enhanced_parser.py - Enhanced NLP with NLTK
import nltk
from nltk.tokenize import word_tokenize
from nltk.corpus import stopwords
from nltk import pos_tag, ne_chunk
import re

class EnhancedParser:
    """Advanced NLP parser using NLTK"""
    
    def __init__(self):
        # Load stopwords
        try:
            self.stop_words = set(stopwords.words('english'))
        except:
            print("⚠️ NLTK stopwords not found. Run setup_nltk.py")
            self.stop_words = set()
        
        print("✅ Enhanced NLP parser initialized")
    
    def extract_location_nlp(self, text):
        """
        Extract location using NLP (better than regex)
        Uses Named Entity Recognition
        """
        try:
            # Tokenize and tag parts of speech
            tokens = word_tokenize(text)
            tagged = pos_tag(tokens)
            
            # Extract named entities
            entities = ne_chunk(tagged, binary=False)
            
            locations = []
            for entity in entities:
                if hasattr(entity, 'label') and entity.label() == 'GPE':  # Geo-Political Entity
                    location = ' '.join([word for word, tag in entity])
                    locations.append(location)
            
            if locations:
                return ' '.join(locations)
            
            # Fallback to pattern matching
            return self._extract_location_patterns(text)
            
        except Exception as e:
            print(f"⚠️ NER failed: {e}, using fallback")
            return self._extract_location_patterns(text)
    
    def _extract_location_patterns(self, text):
        """Fallback pattern-based location extraction"""
        patterns = [
            r'at (.+)',
            r'near (.+)',
            r'on (.+) road',
            r'in (.+)',
            r'(.+) street',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(1).strip()
        
        return text
    
    def extract_injury_count(self, text):
        """Extract number of injured people"""
        # Look for numbers
        numbers = re.findall(r'\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\b', text.lower())
        
        number_map = {
            'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
            'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10
        }
        
        for num in numbers:
            if num.isdigit():
                return int(num)
            elif num in number_map:
                return number_map[num]
        
        return None
    
    def extract_keywords(self, text):
        """Extract important keywords (remove stopwords)"""
        try:
            tokens = word_tokenize(text.lower())
            keywords = [word for word in tokens if word.isalnum() and word not in self.stop_words]
            return keywords
        except:
            # Fallback to simple split
            words = text.lower().split()
            return [w for w in words if len(w) > 3]
    
    def detect_urgency_level(self, text):
        """
        Detect urgency level from language
        Returns: 'critical', 'urgent', or 'normal'
        """
        critical_words = ['dying', 'unconscious', 'not breathing', 'severe bleeding', 
                          'heart attack', 'stroke', 'suicide', 'overdose']
        urgent_words = ['bleeding', 'pain', 'injured', 'accident', 'fire', 
                        'difficulty breathing', 'chest pain']
        
        text_lower = text.lower()
        
        for word in critical_words:
            if word in text_lower:
                return 'critical'
        
        for word in urgent_words:
            if word in text_lower:
                return 'urgent'
        
        return 'normal'
    
    def extract_symptoms(self, text):
        """Extract medical symptoms mentioned"""
        symptom_keywords = [
            'pain', 'bleeding', 'unconscious', 'breathing', 'chest', 
            'dizzy', 'fever', 'vomiting', 'seizure', 'broken', 'burnt'
        ]
        
        symptoms = []
        text_lower = text.lower()
        
        for symptom in symptom_keywords:
            if symptom in text_lower:
                symptoms.append(symptom)
        
        return symptoms
    
    def sentiment_analysis_simple(self, text):
        """
        Simple sentiment analysis (calm vs distressed)
        Returns: float between 0 (calm) and 1 (distressed)
        """
        distress_words = ['help', 'please', 'hurry', 'dying', 'blood', 
                          'emergency', 'quick', 'fast', 'serious']
        
        text_lower = text.lower()
        distress_count = sum(1 for word in distress_words if word in text_lower)
        
        # Normalize to 0-1
        distress_score = min(distress_count / 3, 1.0)
        
        return distress_score
