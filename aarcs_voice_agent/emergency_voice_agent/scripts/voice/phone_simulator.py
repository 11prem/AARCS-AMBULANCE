# phone_simulator.py - Complete Phone Call Simulation System
from voice_input import VoiceInput
from voice_output import VoiceOutput
from modules.intent_parser import IntentParser
from modules.dialogue_manager import DialogueManager
from utils.database import Database
from modules.location_service import LocationService
from ml.ml_classifier import EmergencyClassifier
from modules.enhanced_parser import EnhancedParser
import os
import time
from datetime import datetime
import random

class PhoneCallSimulator:
    """
    Simulates complete phone call system for 108 emergency service
    Demonstrates: Ringing, Call answering, Conversation, Call ending
    """
    
    def __init__(self):
        # Initialize all components
        self.voice_in = VoiceInput()
        self.voice_out = VoiceOutput()
        self.parser = IntentParser()
        self.enhanced_parser = EnhancedParser()
        self.dialogue = DialogueManager()
        self.db = Database()
        self.location_service = LocationService()
        self.ml_classifier = EmergencyClassifier()
        
        # Call metadata
        self.caller_number = self._generate_caller_number()
        self.call_id = self._generate_call_id()
        self.call_start_time = None
        self.call_duration = 0
        
        print("📞 Phone System Initialized")
    
    def _generate_caller_number(self):
        """Generate realistic Indian mobile number"""
        prefixes = ['98', '97', '96', '95', '94', '93', '91', '90', '89', '88']
        prefix = random.choice(prefixes)
        remaining = ''.join([str(random.randint(0, 9)) for _ in range(8)])
        return f"+91-{prefix}{remaining}"
    
    def _generate_call_id(self):
        """Generate unique call ID"""
        timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
        random_suffix = random.randint(1000, 9999)
        return f"CALL-{timestamp}-{random_suffix}"
    
    def simulate_incoming_call(self):
        """Simulate incoming call with ringing animation"""
        print("\n" + "="*80)
        print("📱 INCOMING CALL TO 108 EMERGENCY SERVICE")
        print("="*80)
        print(f"📞 Call ID: {self.call_id}")
        print(f"📱 From: {self.caller_number}")
        print(f"⏰ Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"📍 Network: Jio 4G")
        print("="*80)
        
        # Simulate ringing with animation
        print("\n🔔 Phone Ringing...")
        for i in range(3):
            print(f"   Ring {i+1}... 🔊")
            time.sleep(0.8)
        
        # Auto-answer after 3 rings
        print("\n✅ CALL CONNECTED!")
        print(f"⏱️ Connection established at: {datetime.now().strftime('%H:%M:%S')}")
        print("="*80)
        
        self.call_start_time = time.time()
        
        # Show call in progress
        print("\n📞 CALL IN PROGRESS...")
        print("🎙️ Agent: Speaking")
        print("🎤 Caller: Listening")
        print("-"*80)
    
    def handle_emergency_call(self):
        """Handle the complete emergency call flow"""
        # Step 1: Incoming call simulation
        self.simulate_incoming_call()
        
        # Step 2: Welcome message
        print("\n🗣️ Agent Speaking...")
        self.voice_out.speak("Hello, this is 108 emergency service. I'm here to help you.")
        
        # Step 3: Conversation loop
        question_number = 1
        while not self.dialogue.is_complete():
            question = self.dialogue.get_current_question()
            
            if question:
                print(f"\n📝 Question {question_number}/5")
                print(f"🗣️ Agent: {question}")
                self.voice_out.speak(question)
                
                # Listening phase
                print("🎤 Caller: Speaking...")
                print("⏺️ Recording in progress...")
                
                success, text = self.voice_in.listen(timeout=10)
                
                if success and text:
                    print(f"✅ Recognized: '{text}'")
                    self.dialogue.process_response(text, self.parser, self.enhanced_parser)
                    question_number += 1
                else:
                    print("❌ No clear response detected")
                    print("🗣️ Agent: Asking for clarification...")
                    self.voice_out.speak("I didn't catch that. Let me ask again.")
        
        # Step 4: Process and save call
        self.process_call_completion()
        
        # Step 5: End call
        self.end_call()
    
    def process_call_completion(self):
        """Process collected information and dispatch ambulance"""
        # Calculate call duration
        self.call_duration = time.time() - self.call_start_time
        
        # Get all collected data
        call_data = self.dialogue.get_summary()
        call_data['caller_number'] = self.caller_number
        call_data['call_id'] = self.call_id
        call_data['call_duration'] = int(self.call_duration)
        
        print("\n" + "="*80)
        print("📊 PROCESSING CALL DATA...")
        print("="*80)
        
        # ML classification for unknown emergency types
        if call_data['emergency_type'] == 'unknown' and self.ml_classifier.is_trained:
            print("🤖 Running ML classification...")
            description = call_data.get('description', '')
            if description:
                ml_type, confidence = self.ml_classifier.predict(description)
                if confidence > 0.5:
                    call_data['emergency_type'] = ml_type
                    call_data['confidence'] = confidence
                    print(f"✅ ML Classification: {ml_type.upper()} (confidence: {confidence:.1%})")
        
        # Geocode location
        location_data = None
        if call_data['location']:
            print(f"📍 Geocoding location: '{call_data['location']}'")
            self.voice_out.speak("Let me find your exact location.")
            location_data = self.location_service.get_coordinates(call_data['location'])
            
            if location_data:
                print(f"✅ Location found: {location_data['formatted_address']}")
            else:
                print("⚠️ Location not found in database")
        
        # Save to database
        print("💾 Saving call to database...")
        db_call_id = self.db.save_call(call_data, location_data)
        print(f"✅ Saved with database ID: {db_call_id}")
        
        # Display comprehensive summary
        self.display_call_summary(db_call_id, call_data, location_data)
        
        # Dispatch ambulance
        if location_data:
            self.dispatch_nearest_ambulance(db_call_id, location_data, call_data)
        else:
            print("\n⚠️ Manual dispatch required - Location not confirmed")
            self.voice_out.speak("We couldn't locate you automatically. Our dispatch team will call you back to confirm your location.")
    
    def display_call_summary(self, db_id, call_data, location_data):
        """Display detailed call summary"""
        print("\n" + "="*80)
        print("📋 EMERGENCY CALL SUMMARY")
        print("="*80)
        
        # Call Information
        print("\n🔹 CALL INFORMATION")
        print(f"   Call ID: {self.call_id}")
        print(f"   Database ID: {db_id}")
        print(f"   Caller: {self.caller_number}")
        print(f"   Duration: {int(self.call_duration)} seconds ({int(self.call_duration/60)}:{int(self.call_duration%60):02d})")
        print(f"   Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Emergency Details
        print("\n🔹 EMERGENCY DETAILS")
        print(f"   Type: {call_data['emergency_type'].upper()}")
        print(f"   Urgency Level: {call_data['urgency_level'].upper()}")
        print(f"   Distress Score: {call_data['distress_score']:.2f}/1.0")
        
        if call_data.get('confidence'):
            print(f"   ML Confidence: {call_data['confidence']:.1%}")
        
        if call_data['symptoms']:
            print(f"   Symptoms: {', '.join(call_data['symptoms'])}")
        
        # Location Information
        print("\n🔹 LOCATION INFORMATION")
        print(f"   Reported: {call_data['location']}")
        
        if location_data:
            print(f"   GPS Coordinates: {location_data['latitude']:.4f}, {location_data['longitude']:.4f}")
            print(f"   Full Address: {location_data['formatted_address']}")
            print(f"   Within Service Area: {'✅ Yes' if location_data['within_service_area'] else '⚠️ No'}")
        
        # Incident Information
        print("\n🔹 INCIDENT INFORMATION")
        print(f"   Injuries Reported: {'Yes' if call_data['injuries'] else 'No'}")
        
        if call_data['injury_count']:
            print(f"   Number of Injured: {call_data['injury_count']} person(s)")
        
        print(f"   Currently Safe: {'Yes' if call_data['is_safe'] else 'No'}")
        print(f"   Description: {call_data['description']}")
        
        if call_data['keywords']:
            print(f"   Keywords: {', '.join(call_data['keywords'][:10])}")
        
        print("="*80)
    
    def dispatch_nearest_ambulance(self, db_id, location_data, call_data):
        """Find and dispatch nearest ambulance"""
        print("\n" + "="*80)
        print("🚨 AMBULANCE DISPATCH SYSTEM")
        print("="*80)
        
        # Mock ambulance fleet (replace with real database in production)
        available_ambulances = [
            {'id': 'AMB-108-001', 'lat': 13.0500, 'lng': 80.2500, 'type': 'Basic Life Support'},
            {'id': 'AMB-108-002', 'lat': 13.0800, 'lng': 80.2700, 'type': 'Advanced Life Support'},
            {'id': 'AMB-108-003', 'lat': 12.9700, 'lng': 77.5900, 'type': 'Basic Life Support'},
            {'id': 'AMB-108-004', 'lat': 13.0600, 'lng': 80.2400, 'type': 'Critical Care'},
        ]
        
        print(f"🔍 Searching {len(available_ambulances)} available ambulances...")
        
        # Find nearest
        nearest = self.location_service.find_nearest_ambulance(
            location_data['latitude'],
            location_data['longitude'],
            available_ambulances
        )
        
        if nearest:
            print(f"\n✅ AMBULANCE DISPATCHED!")
            print(f"   Ambulance ID: {nearest['id']}")
            print(f"   Type: {nearest['type']}")
            print(f"   Distance: {nearest['distance_km']} km")
            print(f"   Estimated Arrival: {nearest['eta_minutes']} minutes")
            print(f"   Status: En Route 🚑")
            
            # Update database
            self.db.update_ambulance_dispatch(
                db_id, 
                nearest['id'], 
                int(nearest['eta_minutes'])
            )
            
            # Inform caller based on urgency
            if call_data['urgency_level'] == 'critical':
                message = f"Critical emergency confirmed. Ambulance {nearest['id']} is rushing to your location with emergency lights. Expected arrival in approximately {int(nearest['eta_minutes'])} minutes. Please stay calm and keep the line open if possible."
            elif call_data['urgency_level'] == 'urgent':
                message = f"Ambulance {nearest['id']} is on the way to your location. Expected arrival time is {int(nearest['eta_minutes'])} minutes. Please remain at your current location."
            else:
                message = f"An ambulance has been dispatched to your location. It should arrive in approximately {int(nearest['eta_minutes'])} minutes."
            
            print(f"\n🗣️ Agent informing caller...")
            self.voice_out.speak(message)
            
        else:
            print("\n⚠️ No ambulances currently available")
            print("   Escalating to manual dispatch...")
            self.voice_out.speak("All ambulances are currently responding to other emergencies. Our dispatch team will arrange the nearest available unit and call you back immediately.")
        
        print("="*80)
    
    def end_call(self):
        """End call with proper closure"""
        print("\n" + "="*80)
        print("📞 ENDING CALL...")
        print("="*80)
        
        # Final message
        self.voice_out.speak("Thank you for calling 108. Stay safe. Goodbye.")
        
        # Disconnection animation
        print("\n🔌 Disconnecting...")
        time.sleep(1)
        print("✅ Call Ended Successfully")
        
        # Call statistics
        print(f"\n📊 CALL STATISTICS")
        print(f"   Total Duration: {int(self.call_duration)} seconds")
        print(f"   Questions Asked: 5")
        print(f"   Responses Captured: {sum(1 for v in self.dialogue.get_summary().values() if v)}")
        print(f"   Call Quality: Good ✅")
        
        print("\n" + "="*80)
        print("✅ EMERGENCY CALL PROCESSING COMPLETE")
        print("="*80)

def main():
    """Main function to run phone simulator"""
    print("\n" + "="*80)
    print("📞 108 EMERGENCY SERVICE - PHONE CALL SIMULATOR")
    print("   Phase 3: Phone Integration Demonstration")
    print("="*80)
    print("\nThis simulator demonstrates:")
    print("  ✓ Incoming call handling")
    print("  ✓ Voice-based conversation")
    print("  ✓ Real-time speech recognition")
    print("  ✓ GPS location tracking")
    print("  ✓ ML-based classification")
    print("  ✓ Ambulance dispatch system")
    print("="*80)
    
    input("\n▶️ Press Enter to simulate an incoming emergency call...")
    
    # Create simulator instance
    simulator = PhoneCallSimulator()
    
    # Handle the call
    try:
        simulator.handle_emergency_call()
    except KeyboardInterrupt:
        print("\n\n⚠️ Call interrupted by user")
        simulator.end_call()
    except Exception as e:
        print(f"\n\n❌ Error during call: {e}")
        import traceback
        traceback.print_exc()
    
    print("\n✅ Phone Simulator Demo Complete!")
    print("="*80)

if __name__ == "__main__":
    # Ensure necessary directories exist
    os.makedirs('data', exist_ok=True)
    os.makedirs('models', exist_ok=True)
    
    main()
