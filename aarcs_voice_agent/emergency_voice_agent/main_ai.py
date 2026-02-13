# main_ai.py - Fixed with voice debugging
import os
import sys
from datetime import datetime

# ========== FIX IMPORT PATHS ==========
current_dir = os.path.dirname(os.path.abspath(__file__))
scripts_dir = os.path.join(current_dir, 'scripts')

# Add to Python path
sys.path.insert(0, current_dir)  # emergency_voice_agent
sys.path.insert(0, scripts_dir)  # emergency_voice_agent/scripts

# Now import all modules
try:
    from voice.voice_input import VoiceInput
    from voice.voice_output import VoiceOutput
    from modules.intent_parser import IntentParser
    from utils.database import Database
    from modules.location_service import LocationService
    from ml.ml_classifier import EmergencyClassifier
    from modules.enhanced_parser import EnhancedParser
    from ai_question_generator import DynamicDialogueManager
    print("✅ All imports successful")
except ImportError as e:
    print(f"❌ Import Error: {e}")
    print("Trying alternative imports...")
    
    # Try alternative import paths
    try:
        from scripts.voice.voice_input import VoiceInput
        from scripts.voice.voice_output import VoiceOutput
        from scripts.modules.intent_parser import IntentParser
        from scripts.utils.database import Database
        from scripts.modules.location_service import LocationService
        from scripts.ml.ml_classifier import EmergencyClassifier
        from scripts.modules.enhanced_parser import EnhancedParser
        from ai_question_generator import DynamicDialogueManager
        print("✅ Imports successful via scripts path")
    except ImportError as e2:
        print(f"❌ Still getting import error: {e2}")
        sys.exit(1)

# ========== ADD MONITOR SUPPORT ==========
try:
    # Try to import monitor client
    sys.path.insert(0, os.path.dirname(__file__))  # Add current directory
    from real_time_monitor import MonitorClient
    monitor_client = MonitorClient()
    print("✅ Connected to real-time monitor")
except ImportError as e:
    monitor_client = None
    print("⚠️  Real-time monitor not available (run real_time_monitor.py first)")
except Exception as e:
    monitor_client = None
    print(f"⚠️  Could not connect to monitor: {e}")

def send_to_monitor(msg_type, data):
    """Helper to send data to monitor"""
    if monitor_client:
        return monitor_client.send(msg_type, data)
    return False

# ========== VOICE DEBUGGING ==========
class DebugVoiceInput:
    """Wrapper for VoiceInput with debugging"""
    
    def __init__(self, voice_input):
        self.voice_input = voice_input
    
    def listen(self, timeout=10):
        """Listen with debug info"""
        print(f"\n🎤 Listening for speech (timeout: {timeout}s)...")
        print("   Speak now...")
        
        try:
            success, text = self.voice_input.listen(timeout=timeout)
            
            if success:
                print(f"✅ Speech recognized: '{text}'")
                return True, text
            else:
                print("❌ No speech detected or recognition failed")
                return False, ""
                
        except Exception as e:
            print(f"⚠️  Voice recognition error: {e}")
            return False, ""

# ========== RELIABLE VOICE INPUT ==========
# Use ReliableVoiceInput if available, fallback to VoiceInput
try:
    from voice_input_fixed import ReliableVoiceInput
    voice_in_raw = ReliableVoiceInput()
    print("✅ Using ReliableVoiceInput (enhanced voice recognition)")
except ImportError as e:
    print(f"⚠️  ReliableVoiceInput not available: {e}")
    print("📢 Using standard VoiceInput")
    from voice.voice_input import VoiceInput
    voice_in_raw = VoiceInput()
except Exception as e:
    print(f"⚠️  Error loading ReliableVoiceInput: {e}")
    print("📢 Falling back to standard VoiceInput")
    from voice.voice_input import VoiceInput
    voice_in_raw = VoiceInput()

# ========== SIMPLIFIED DIALOGUE ==========
class SimpleDialogueManager:
    """Simplified dialogue manager that works with your existing flow"""
    
    def __init__(self):
        self.questions = [
            "What kind of emergency are you facing?",
            "Where are you located right now?",
            "Is anyone injured?",
            "Are you in a safe place?",
            "Can you describe what happened?"
        ]
        self.current_question = 0
        self.responses = {}
        self.completed = False
    
    def get_current_question(self):
        """Get current question"""
        if self.current_question < len(self.questions):
            return self.questions[self.current_question]
        return None
    
    def process_response(self, response, parser, enhanced_parser=None):
        """Process response and advance to next question"""
        if self.current_question == 0:  # Emergency type
            self.responses['emergency_type'] = parser.extract_emergency_type(response)
            if enhanced_parser:
                self.responses['urgency_level'] = enhanced_parser.detect_urgency_level(response)
        elif self.current_question == 1:  # Location
            if enhanced_parser:
                self.responses['location'] = enhanced_parser.extract_location_nlp(response)
            else:
                self.responses['location'] = parser.extract_location(response)
        elif self.current_question == 2:  # Injuries
            self.responses['injuries'] = parser.detect_yes_no(response)
        elif self.current_question == 3:  # Safety
            self.responses['is_safe'] = parser.detect_yes_no(response)
        elif self.current_question == 4:  # Description
            self.responses['description'] = response
        
        # Move to next question
        self.current_question += 1
        
        # Check if completed
        if self.current_question >= len(self.questions):
            self.completed = True
    
    def is_complete(self):
        """Check if dialogue is complete"""
        return self.completed
    
    def get_summary(self):
        """Get summary of all responses"""
        # Ensure all keys exist
        default_data = {
            'emergency_type': 'unknown',
            'location': None,
            'injuries': None,
            'injury_count': None,
            'is_safe': None,
            'description': None,
            'keywords': [],
            'urgency_level': 'normal',
            'symptoms': [],
            'distress_score': 0.0,
            'confidence': 0.0,
            'detailed_responses': {}
        }
        
        # Merge with actual responses
        for key, value in self.responses.items():
            default_data[key] = value
        
        # Create detailed responses for display
        for i, question in enumerate(self.questions):
            if i < len(self.questions) - 1:  # Skip last question if not answered yet
                # Store question-answer pairs
                default_data['detailed_responses'][question] = ""
        
        return default_data

# ========== MAIN FUNCTION ==========
def main():
    print("=" * 80)
    print("🚑 108 EMERGENCY VOICE AGENT - DEBUG VERSION")
    print("   With Voice Debugging & Fallback")
    print("=" * 80)
    
    # Track call start time
    call_start_time = datetime.now()
    
    # Notify monitor about call start
    send_to_monitor('call_started', {'start_time': call_start_time.isoformat()})
    
    # Initialize all components
    # voice_in_raw is already initialized above with ReliableVoiceInput fallback
    voice_in = DebugVoiceInput(voice_in_raw)  # Use debug wrapper
    voice_out = VoiceOutput()
    parser = IntentParser()
    enhanced_parser = EnhancedParser()
    db = Database()
    location_service = LocationService()
    ml_classifier = EmergencyClassifier()
    
    # Use simple dialogue manager instead of AI one
    dialogue = SimpleDialogueManager()
    
    # Welcome message
    welcome_msg = "Hello, this is 108 emergency service. I'm here to help you."
    voice_out.speak(welcome_msg)
    send_to_monitor('ai_response', {'text': welcome_msg})
    
    print("\n" + "=" * 80)
    print("STEP 1: EMERGENCY ASSESSMENT")
    print("=" * 80)
    
    # Conversation loop
    question_count = 0
    while not dialogue.is_complete():
        question = dialogue.get_current_question()
        
        if question:
            question_count += 1
            print(f"\n📝 Question {question_count}: {question}")
            voice_out.speak(question)
            send_to_monitor('ai_response', {'text': question})
            
            # Get response with debugging
            print("\n" + "-" * 40)
            success, response = voice_in.listen(timeout=10)
            print("-" * 40)
            
            if success and response:
                print(f"✅ Response received: '{response}'")
                send_to_monitor('user_speech', {'text': response})
                
                # Process response
                dialogue.process_response(response, parser, enhanced_parser)
                
                # Show what was extracted
                if question_count == 1:
                    emergency_type = dialogue.responses.get('emergency_type', 'unknown')
                    print(f"🔍 Emergency type identified: {emergency_type.upper()}")
                    send_to_monitor('emergency_info', {
                        'type': emergency_type,
                        'description': response
                    })
                elif question_count == 2:
                    location = dialogue.responses.get('location', '')
                    print(f"📍 Location identified: {location}")
                    send_to_monitor('location_text', {'text': location})
            else:
                print("⚠️ No valid response, asking again...")
                voice_out.speak("I didn't understand. Could you please repeat?")
        else:
            print("\n✅ All questions completed")
            break
    
    # Get all collected data
    call_data = dialogue.get_summary()
    
    print("\n" + "=" * 80)
    print("STEP 2: LOCATION PROCESSING")
    print("=" * 80)
    
    # Process location if available
    location_data = None
    if call_data['location']:
        print(f"🔍 Processing location: '{call_data['location']}'")
        
        try:
            # Get location coordinates
            location_result, needs_confirmation, alternatives = location_service.get_coordinates_with_confirmation(
                call_data['location'],
                voice_out
            )
            
            if location_result:
                # Send location coordinates to monitor
                send_to_monitor('location_info', {
                    'address': location_result['formatted_address'],
                    'latitude': location_result['latitude'],
                    'longitude': location_result['longitude'],
                    'in_service_area': location_result['within_service_area']
                })
                
                location_data = location_result
                print(f"📍 Location identified: {location_result['formatted_address']}")
                print(f"   GPS: {location_result['latitude']:.4f}, {location_result['longitude']:.4f}")
        except Exception as e:
            print(f"⚠️ Location processing error: {e}")
            location_data = None
    else:
        print("⚠️ No location provided")
    
    print("\n" + "=" * 80)
    print("STEP 3: SAVE TO DATABASE")
    print("=" * 80)
    
    # Save call to database
    try:
        call_id = db.save_call(call_data, location_data)
        print(f"✅ Call saved with Database ID: {call_id}")
    except Exception as e:
        print(f"⚠️ Database error: {e}")
        call_id = 1  # Default ID for testing
    
    print("\n" + "=" * 80)
    print("📋 CALL SUMMARY")
    print("=" * 80)
    print(f"Call ID: {call_id}")
    print(f"Emergency Type: {call_data['emergency_type'].upper()}")
    print(f"Questions Asked: {question_count}")
    
    # Display collected information
    print("\n📝 Collected Information:")
    print("-" * 40)
    if call_data['location']:
        print(f"📍 Location: {call_data['location']}")
    if location_data:
        print(f"   Address: {location_data['formatted_address']}")
        print(f"   GPS: {location_data['latitude']:.4f}, {location_data['longitude']:.4f}")
    print(f"🩹 Injuries: {'Yes' if call_data['injuries'] else 'No'}")
    print(f"🛡️ Currently Safe: {'Yes' if call_data['is_safe'] else 'No'}")
    if call_data['description']:
        print(f"📖 Description: {call_data['description'][:100]}...")
    print("-" * 40)
    
    print("\n" + "=" * 80)
    print("STEP 4: DISPATCH AMBULANCE")
    print("=" * 80)
    
    # Dispatch ambulance
    if location_data:
        # Mock ambulance fleet
        mock_ambulances = [
            {'id': 'AMB-108-001', 'lat': 13.0500, 'lng': 80.2500},
            {'id': 'AMB-108-002', 'lat': 13.0800, 'lng': 80.2700},
            {'id': 'AMB-108-003', 'lat': 12.9700, 'lng': 77.5900},
        ]
        
        try:
            nearest = location_service.find_nearest_ambulance(
                location_data['latitude'],
                location_data['longitude'],
                mock_ambulances
            )
            
            if nearest:
                print(f"🚑 Ambulance: {nearest['id']}")
                print(f"   Distance: {nearest['distance_km']} km")
                print(f"   ETA: {nearest['eta_minutes']} minutes")
                
                # Send ambulance info to monitor
                send_to_monitor('ambulance_info', {
                    'id': nearest['id'],
                    'distance_km': nearest['distance_km'],
                    'eta_minutes': nearest['eta_minutes'],
                    'status': 'dispatched'
                })
                
                # Update database if possible
                try:
                    db.update_ambulance_dispatch(call_id, nearest['id'], int(nearest['eta_minutes']))
                except:
                    pass
                
                # Speak message
                urgency = call_data.get('urgency_level', 'normal')
                if urgency == 'critical':
                    message = f"Critical emergency. Ambulance {nearest['id']} is rushing to your location. Expected arrival in {int(nearest['eta_minutes'])} minutes. Stay calm."
                elif urgency == 'urgent':
                    message = f"Help is on the way. Ambulance arriving in approximately {int(nearest['eta_minutes'])} minutes."
                else:
                    message = f"Ambulance has been dispatched. Estimated arrival time is {int(nearest['eta_minutes'])} minutes."
                
                voice_out.speak(message)
                send_to_monitor('ai_response', {'text': message})
            else:
                print("⚠️ No ambulances available")
                message = "All ambulances are currently busy. Manual dispatch initiated."
                voice_out.speak(message)
                send_to_monitor('ai_response', {'text': message})
                
        except Exception as e:
            print(f"⚠️ Ambulance dispatch error: {e}")
            message = "We're having trouble finding an ambulance. Manual dispatch initiated."
            voice_out.speak(message)
            send_to_monitor('ai_response', {'text': message})
    else:
        print("⚠️ Location not confirmed - manual dispatch required")
        message = "We couldn't confirm your location. Our team will call you back shortly."
        voice_out.speak(message)
        send_to_monitor('ai_response', {'text': message})
    
    # Generate final summary
    call_duration = datetime.now() - call_start_time
    call_summary = {
        'emergency_type': call_data['emergency_type'],
        'location': call_data['location'],
        'duration': str(call_duration),
        'questions_asked': question_count,
        'injuries': call_data.get('injuries'),
        'is_safe': call_data.get('is_safe'),
        'urgency': call_data.get('urgency_level', 'normal'),
        'call_id': call_id,
        'timestamp': call_start_time.strftime("%Y-%m-%d %H:%M:%S"),
        'status': 'completed'
    }
    
    if location_data:
        call_summary['location_details'] = {
            'address': location_data['formatted_address'],
            'coordinates': f"{location_data['latitude']:.4f}, {location_data['longitude']:.4f}"
        }
    
    # Send final summary to monitor
    send_to_monitor('call_summary', call_summary)
    send_to_monitor('call_ended', {})
    
    print("\n" + "=" * 80)
    print("✅ EMERGENCY CALL COMPLETE")
    print("=" * 80)
    
    # Show final summary
    print("\n" + "=" * 80)
    print("📋 FINAL CALL REPORT")
    print("=" * 80)
    print(f"Call ID: {call_id}")
    print(f"Start Time: {call_start_time.strftime('%H:%M:%S')}")
    print(f"Duration: {call_duration}")
    print(f"Emergency Type: {call_data['emergency_type'].upper()}")
    print(f"Location: {call_data.get('location', 'Not specified')}")
    
    if location_data:
        print(f"Verified Address: {location_data['formatted_address']}")
    
    if 'ambulance_info' in locals() and nearest:
        print(f"Ambulance: {nearest['id']}")
        print(f"ETA: {nearest['eta_minutes']} minutes")
        print(f"Distance: {nearest['distance_km']} km")
    
    print(f"Questions Asked: {question_count}")
    print("=" * 80)
    
    # Close monitor connection
    if monitor_client:
        monitor_client.close()

if __name__ == "__main__":
    # Create necessary directories
    os.makedirs('data', exist_ok=True)
    os.makedirs('models', exist_ok=True)
    
    print("\n🎯 Starting 108 Emergency Agent (Debug Mode)...")
    print("This version has voice debugging and text fallback")
    print("\n" + "="*80)
    
    main()