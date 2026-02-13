# dialogue_manager.py - Fixed version
from config import CONFIG

class DialogueManager:
    """Enhanced conversation manager with location confirmation"""
    
    def __init__(self):
        self.state = 0
        self.awaiting_location_confirmation = False
        self.location_alternatives = []
        self.data = {
            'emergency_type': None,
            'location': None,
            'location_confirmed': False,
            'injuries': None,
            'injury_count': None,
            'is_safe': None,
            'description': None,
            'keywords': [],
            'urgency_level': 'normal',
            'symptoms': [],
            'distress_score': 0.0,
            'confidence': 0.0
        }
    
    def get_current_question(self):
        """Get current question with special handling for location confirmation"""
        # If awaiting location confirmation
        if self.awaiting_location_confirmation:
            if self.location_alternatives:
                # Multiple options
                alternatives_text = ", ".join([
                    f"option {i+1}: {alt['name'].title()}"
                    for i, alt in enumerate(self.location_alternatives[:3])
                ])
                return f"I found multiple locations: {alternatives_text}. Which one is correct? Please say the option number or the full name again."
            else:
                # Single location confirmation
                return f"I heard {self.data['location']}. Is this correct? Please say yes or no."
        
        # Normal questions
        if self.state < len(CONFIG['questions']):
            return CONFIG['questions'][self.state]
        
        return None
    
    def process_response(self, text, parser, enhanced_parser=None):
        """Process response with location confirmation handling"""
        
        # Handle location confirmation
        if self.awaiting_location_confirmation:
            return self._handle_location_confirmation(text, parser)
        
        # Normal question processing
        if self.state == 0:  # Emergency type
            self.data['emergency_type'] = parser.extract_emergency_type(text)
            if enhanced_parser:
                self.data['urgency_level'] = enhanced_parser.detect_urgency_level(text)
                self.data['symptoms'] = enhanced_parser.extract_symptoms(text)
                self.data['distress_score'] = enhanced_parser.sentiment_analysis_simple(text)
            self.state += 1  # Advance state
            
        elif self.state == 1:  # Location
            if enhanced_parser:
                self.data['location'] = enhanced_parser.extract_location_nlp(text)
            else:
                self.data['location'] = parser.extract_location(text)
            # IMPORTANT: Advance state here too!
            self.state += 1
            
        elif self.state == 2:  # Injuries
            self.data['injuries'] = parser.detect_yes_no(text)
            if enhanced_parser:
                count = enhanced_parser.extract_injury_count(text)
                if count:
                    self.data['injury_count'] = count
            self.state += 1
            
        elif self.state == 3:  # Safety
            self.data['is_safe'] = parser.detect_yes_no(text)
            self.state += 1
            
        elif self.state == 4:  # Description
            self.data['description'] = text
            if enhanced_parser:
                self.data['keywords'] = enhanced_parser.extract_keywords(text)
            self.state += 1
    
    def _handle_location_confirmation(self, text, parser):
        """Handle location confirmation response"""
        text_lower = text.lower()
        
        if self.location_alternatives:
            # Check if user said option number
            if 'option 1' in text_lower or text_lower.strip() in ['1', 'one', 'first']:
                self.data['location'] = self.location_alternatives[0]['name']
                self.data['location_confirmed'] = True
                self.awaiting_location_confirmation = False
                return
            elif 'option 2' in text_lower or text_lower.strip() in ['2', 'two', 'second']:
                if len(self.location_alternatives) > 1:
                    self.data['location'] = self.location_alternatives[1]['name']
                    self.data['location_confirmed'] = True
                    self.awaiting_location_confirmation = False
                    return
            elif 'option 3' in text_lower or text_lower.strip() in ['3', 'three', 'third']:
                if len(self.location_alternatives) > 2:
                    self.data['location'] = self.location_alternatives[2]['name']
                    self.data['location_confirmed'] = True
                    self.awaiting_location_confirmation = False
                    return
            
            # Check if user said full name again
            for alt in self.location_alternatives:
                if alt['name'].lower() in text_lower:
                    self.data['location'] = alt['name']
                    self.data['location_confirmed'] = True
                    self.awaiting_location_confirmation = False
                    return
            
            # If none matched, use what they said
            self.data['location'] = text
            self.data['location_confirmed'] = False
            self.awaiting_location_confirmation = False
        else:
            # Simple yes/no confirmation
            yes_no = parser.detect_yes_no(text)
            if yes_no == True:
                self.data['location_confirmed'] = True
                self.awaiting_location_confirmation = False
            elif yes_no == False:
                # Ask again - keep location as None
                self.data['location'] = None
                self.awaiting_location_confirmation = False
                self.state = 1  # Go back to location question
            else:
                # Unclear response, assume they're giving location again
                self.data['location'] = text
                self.awaiting_location_confirmation = False
    
    def trigger_location_confirmation(self, alternatives=None):
        """Trigger location confirmation flow"""
        self.awaiting_location_confirmation = True
        if alternatives:
            self.location_alternatives = alternatives
    
    def is_complete(self):
        """Check if conversation complete"""
        return self.state >= len(CONFIG['questions']) and not self.awaiting_location_confirmation
    
    def get_summary(self):
        """Get summary"""
        return self.data
