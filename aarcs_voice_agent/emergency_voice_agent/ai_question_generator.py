# ai_question_generator.py - AI-Based Dynamic Question System
import os
from openai import OpenAI

class AIQuestionGenerator:
    """
    AI-based question generator that adapts to emergency type
    Generates context-aware questions dynamically
    """
    
    def __init__(self, use_openai=False):
        self.use_openai = use_openai
        
        if use_openai:
            # OpenAI API (optional - requires API key)
            self.client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
            print("✅ AI Question Generator initialized (OpenAI)")
        else:
            # Rule-based fallback (free)
            print("✅ AI Question Generator initialized (Rule-based)")
        
        # Emergency-specific question templates
        self.question_templates = self._init_question_templates()
        
        # Track conversation history
        self.conversation_history = []
        self.emergency_context = {}
    
    def _init_question_templates(self):
        """Initialize emergency-specific question templates"""
        return {
            'accident': {
                'priority_questions': [
                    "What type of accident? Vehicle, bike, or pedestrian?",
                    "Where exactly did the accident occur?",
                    "How many people are involved?",
                    "Is anyone trapped or unable to move?",
                    "Are there any visible injuries like bleeding or broken bones?",
                    "Is the accident location blocking traffic?",
                    "Are there any fire hazards like fuel leaks?"
                ],
                'follow_up': {
                    'vehicle': [
                        "How many vehicles are involved?",
                        "Are any vehicles overturned?",
                        "Is anyone still inside the vehicles?"
                    ],
                    'trapped': [
                        "Where exactly is the person trapped?",
                        "Is the person conscious?",
                        "Can you see any injuries?"
                    ],
                    'bleeding': [
                        "Where is the bleeding from?",
                        "Is it heavy bleeding or minor?",
                        "Is the person conscious?"
                    ]
                }
            },
            
            'medical': {
                'priority_questions': [
                    "What medical emergency are you facing?",
                    "Where is the patient located right now?",
                    "Is the patient conscious and breathing?",
                    "What are the main symptoms?",
                    "Does the patient have any known medical conditions?",
                    "How old is the patient?",
                    "When did the symptoms start?"
                ],
                'follow_up': {
                    'chest_pain': [
                        "Where exactly is the chest pain?",
                        "Is the pain radiating to the arm or jaw?",
                        "Is the patient sweating or feeling dizzy?",
                        "Does the patient have a history of heart problems?"
                    ],
                    'unconscious': [
                        "Is the patient breathing?",
                        "Can you feel a pulse?",
                        "Are there any visible injuries?",
                        "Did the patient fall or hit their head?"
                    ],
                    'breathing': [
                        "Can the patient speak in full sentences?",
                        "Are their lips or face turning blue?",
                        "Do they have asthma or other lung conditions?",
                        "Is there any wheezing sound?"
                    ],
                    'seizure': [
                        "Is the seizure still happening?",
                        "How long has it been going on?",
                        "Is this the first seizure or does the patient have epilepsy?",
                        "Is there anything in the mouth?"
                    ]
                }
            },
            
            'fire': {
                'priority_questions': [
                    "Where is the fire? Building, vehicle, or outdoor?",
                    "What is the exact location?",
                    "How big is the fire?",
                    "Are there people trapped inside?",
                    "Are there any explosions or gas cylinders nearby?",
                    "Is the fire spreading?",
                    "Is everyone evacuated?"
                ],
                'follow_up': {
                    'trapped': [
                        "How many people are trapped?",
                        "Which floor or area are they in?",
                        "Is there smoke inhalation?",
                        "Are there alternate exits?"
                    ],
                    'spreading': [
                        "What direction is the fire spreading?",
                        "Are nearby buildings at risk?",
                        "Is there anything flammable nearby?"
                    ]
                }
            },
            
            'assault': {
                'priority_questions': [
                    "Are you currently safe from the attacker?",
                    "Where are you located right now?",
                    "Are you injured?",
                    "Is the attacker still nearby?",
                    "What type of assault - physical, weapon involved?",
                    "Do you need police assistance as well?"
                ],
                'follow_up': {
                    'weapon': [
                        "What type of weapon?",
                        "Where are you injured?",
                        "Is the bleeding severe?"
                    ],
                    'unsafe': [
                        "Can you move to a safe location?",
                        "Are there people nearby who can help?",
                        "Can you lock yourself in a room?"
                    ]
                }
            },
            
            'other': {
                'priority_questions': [
                    "Can you describe the emergency situation?",
                    "Where are you located?",
                    "Is anyone injured or in danger?",
                    "Are you currently safe?",
                    "What immediate help do you need?"
                ]
            }
        }
    
    def get_initial_questions(self, emergency_type):
        """Get initial questions based on emergency type"""
        template = self.question_templates.get(emergency_type, self.question_templates['other'])
        return template['priority_questions'][:5]  # Start with first 5
    
    def generate_next_question(self, emergency_type, conversation_history):
        """
        Generate next question based on context
        Uses AI if available, otherwise rule-based
        """
        if self.use_openai:
            return self._generate_with_ai(emergency_type, conversation_history)
        else:
            return self._generate_rule_based(emergency_type, conversation_history)
    
    def _generate_rule_based(self, emergency_type, conversation_history):
        """Rule-based question generation (free alternative)"""
        # Get base questions for this emergency type
        template = self.question_templates.get(emergency_type, self.question_templates['other'])
        base_questions = template['priority_questions']
        
        # Check which questions have been asked
        asked_count = len([q for q in conversation_history if q['role'] == 'agent'])
        
        # If we've asked all base questions, check for follow-ups
        if asked_count >= len(base_questions):
            # Look for keywords in user responses to determine follow-ups
            user_responses = [q['content'].lower() for q in conversation_history if q['role'] == 'user']
            all_responses = ' '.join(user_responses)
            
            # Check for follow-up triggers
            follow_ups = template.get('follow_up', {})
            for trigger, questions in follow_ups.items():
                if trigger in all_responses:
                    # Return first unanswered follow-up question
                    for question in questions:
                        if not any(question.lower() in q['content'].lower() for q in conversation_history):
                            return question
            
            return None  # No more questions
        
        # Return next base question
        return base_questions[asked_count]
    
    def _generate_with_ai(self, emergency_type, conversation_history):
        """AI-based question generation using OpenAI"""
        try:
            # Build conversation context
            messages = [
                {
                    "role": "system",
                    "content": f"""You are an emergency dispatcher for 108 ambulance service in India. 
                    Current emergency type: {emergency_type}
                    
                    Your job is to ask ONE critical question at a time to gather essential information for dispatching help.
                    
                    Rules:
                    1. Ask only ONE question
                    2. Keep questions short and clear (under 20 words)
                    3. Focus on: location details, injury severity, safety status, specific symptoms
                    4. Don't repeat questions already asked
                    5. Prioritize life-threatening information first
                    6. If all critical info gathered, return "COMPLETE"
                    
                    Be empathetic but efficient."""
                }
            ]
            
            # Add conversation history
            messages.extend(conversation_history)
            
            # Generate next question
            response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=messages,
                max_tokens=50,
                temperature=0.7
            )
            
            question = response.choices[0].message.content.strip()
            
            # Check if conversation should end
            if "COMPLETE" in question.upper():
                return None
            
            return question
            
        except Exception as e:
            print(f"⚠️ AI generation failed: {e}, falling back to rule-based")
            return self._generate_rule_based(emergency_type, conversation_history)
    
    def should_continue_questions(self, emergency_type, conversation_history):
        """Determine if more questions are needed"""
        # Minimum questions asked
        asked_count = len([q for q in conversation_history if q['role'] == 'agent'])
        
        # Must ask at least 3 questions
        if asked_count < 3:
            return True
        
        # Check if critical information is collected
        critical_info = {
            'location': False,
            'severity': False,
            'safety': False
        }
        
        user_responses = ' '.join([
            q['content'].lower() 
            for q in conversation_history 
            if q['role'] == 'user'
        ])
        
        # Check for location keywords
        location_keywords = ['at', 'near', 'in', 'on', 'road', 'street', 'area']
        critical_info['location'] = any(kw in user_responses for kw in location_keywords)
        
        # Check for severity indicators
        severity_keywords = ['injured', 'bleeding', 'unconscious', 'pain', 'trapped', 'yes', 'no']
        critical_info['severity'] = any(kw in user_responses for kw in severity_keywords)
        
        # Check for safety status
        safety_keywords = ['safe', 'danger', 'threat', 'trapped', 'escaped']
        critical_info['safety'] = any(kw in user_responses for kw in safety_keywords)
        
        # Continue if any critical info is missing and we haven't asked too many questions
        if asked_count < 7 and not all(critical_info.values()):
            return True
        
        return False


class DynamicDialogueManager:
    """
    Enhanced dialogue manager that uses AI for dynamic questions
    """
    
    def __init__(self, use_openai=False):
        self.ai_generator = AIQuestionGenerator(use_openai=use_openai)
        self.conversation_history = []
        self.emergency_type = None
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
            'confidence': 0.0,
            'detailed_responses': {}  # Store all Q&A pairs
        }
    
    def start_conversation(self, emergency_type):
        """Initialize conversation with emergency type"""
        self.emergency_type = emergency_type
        self.data['emergency_type'] = emergency_type
        
        # Get initial questions for this emergency type
        self.questions = self.ai_generator.get_initial_questions(emergency_type)
        self.current_question_index = 0
        
        print(f"✅ Dynamic conversation started for: {emergency_type}")
    
    def get_current_question(self):
        """Get next question dynamically"""
        # Handle location confirmation first
        if self.awaiting_location_confirmation:
            if self.location_alternatives:
                alternatives_text = ", ".join([
                    f"option {i+1}: {alt['name'].title()}"
                    for i, alt in enumerate(self.location_alternatives[:3])
                ])
                return f"I found multiple locations: {alternatives_text}. Which one is correct?"
            else:
                return f"I heard {self.data['location']}. Is this correct?"
        
        # Use pre-loaded questions first
        if self.current_question_index < len(self.questions):
            return self.questions[self.current_question_index]
        
        # Generate next question dynamically
        if self.ai_generator.should_continue_questions(self.emergency_type, self.conversation_history):
            next_question = self.ai_generator.generate_next_question(
                self.emergency_type,
                self.conversation_history
            )
            
            if next_question:
                return next_question
        
        return None  # No more questions
    
    def process_response(self, question, response, parser, enhanced_parser):
        """Process user response and extract information"""
        # Add to conversation history
        self.conversation_history.append({
            'role': 'agent',
            'content': question
        })
        self.conversation_history.append({
            'role': 'user',
            'content': response
        })
        
        # Store detailed response
        self.data['detailed_responses'][question] = response
        
        # Extract information based on question type
        response_lower = response.lower()
        
        # Location extraction
        if 'location' in question.lower() or 'where' in question.lower():
            if enhanced_parser:
                self.data['location'] = enhanced_parser.extract_location_nlp(response)
            else:
                self.data['location'] = response
        
        # Injury/severity extraction
        if 'injur' in question.lower() or 'hurt' in question.lower():
            self.data['injuries'] = parser.detect_yes_no(response)
            if enhanced_parser:
                count = enhanced_parser.extract_injury_count(response)
                if count:
                    self.data['injury_count'] = count
        
        # Safety extraction
        if 'safe' in question.lower():
            self.data['is_safe'] = parser.detect_yes_no(response)
        
        # Symptoms extraction
        if enhanced_parser:
            symptoms = enhanced_parser.extract_symptoms(response)
            if symptoms:
                self.data['symptoms'].extend(symptoms)
            
            # Update urgency
            urgency = enhanced_parser.detect_urgency_level(response)
            if urgency != 'normal':
                self.data['urgency_level'] = urgency
        
        # Move to next question
        self.current_question_index += 1
    
    def is_complete(self):
        """Check if conversation is complete"""
        if self.awaiting_location_confirmation:
            return False
        
        # Must have emergency type
        if not self.emergency_type:
            return False
        
        # Check if we have enough information
        has_location = bool(self.data.get('location'))
        has_responses = len(self.conversation_history) >= 6  # At least 3 Q&A pairs
        
        # Check if AI says we're done
        no_more_questions = self.get_current_question() is None
        
        return (has_location and has_responses) or no_more_questions
    
    def trigger_location_confirmation(self, alternatives=None):
        """Trigger location confirmation"""
        self.awaiting_location_confirmation = True
        if alternatives:
            self.location_alternatives = alternatives
    
    def get_summary(self):
        """Get complete conversation summary"""
        return self.data
