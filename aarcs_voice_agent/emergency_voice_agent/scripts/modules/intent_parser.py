from config import EMERGENCY_KEYWORDS
import re

class IntentParser:
    """Rule-based NLP - No AI APIs needed"""
    
    def extract_emergency_type(self, text):
        """Identify emergency type from keywords"""
        text = text.lower()
        
        for emergency_type, keywords in EMERGENCY_KEYWORDS.items():
            for keyword in keywords:
                if keyword in text:
                    return emergency_type
        
        return 'unknown'
    
    def extract_location(self, text):
        """Extract location from speech"""
        text = text.lower()
        
        # Look for common location patterns
        location_patterns = [
            r'at (.+)',
            r'near (.+)',
            r'in (.+)',
            r'on (.+) road',
            r'(.+) street',
        ]
        
        for pattern in location_patterns:
            match = re.search(pattern, text)
            if match:
                return match.group(1).strip()
        
        # If no pattern matches, return full text
        return text
    
    def detect_yes_no(self, text):
        """Detect yes/no response"""
        text = text.lower()
        
        yes_words = ['yes', 'yeah', 'yep', 'correct', 'right', 'sure']
        no_words = ['no', 'nope', 'not', 'negative']
        
        for word in yes_words:
            if word in text:
                return True
        
        for word in no_words:
            if word in text:
                return False
        
        return None  # Unclear response
