# main.py - Phase 2 with GPS, ML & NLTK
from voice.voice_input import VoiceInput
from voice.voice_output import VoiceOutput
from modules.intent_parser import IntentParser
from modules.dialogue_manager import DialogueManager
from utils.database import Database
from modules.location_service import LocationService
from ml.ml_classifier import EmergencyClassifier
from modules.enhanced_parser import EnhancedParser
import os

def main():
    print("=" * 70)
    print("🚑 108 Emergency Voice Agent - Phase 2")
    print("   Enhanced with GPS, ML Classification & NLTK")
    print("=" * 70)
    
    # Initialize all components
    voice_in = VoiceInput()
    voice_out = VoiceOutput()
    parser = IntentParser()
    enhanced_parser = EnhancedParser()
    dialogue = DialogueManager()
    db = Database()
    location_service = LocationService()
    ml_classifier = EmergencyClassifier()
    
    # Welcome message
    voice_out.speak("Hello, this is 108 emergency service. I'm here to help you.")
    
    # Conversation loop
    while not dialogue.is_complete():
        question = dialogue.get_current_question()
        
        if question:
            voice_out.speak(question)
            
            # Listen for response
            success, text = voice_in.listen(timeout=10)
            
            if success and text:
                # Process with BOTH parsers
                dialogue.process_response(text, parser, enhanced_parser)
            else:
                voice_out.speak("I didn't catch that. Let me ask again.")
    
    # Collect all data
    call_data = dialogue.get_summary()
    
    # ============================================================================
    # PASTE THE ENHANCED LOCATION PROCESSING CODE HERE (BETWEEN LINE 74-75)
    # ============================================================================
    
    # Enhanced location processing with confirmation
    location_data = None
    if call_data['location']:
        print("\n🔍 Processing location...")
        
        # Get location with potential confirmation needed
        location_result, needs_confirmation, alternatives = location_service.get_coordinates_with_confirmation(
            call_data['location'],
            voice_out
        )
        
        if location_result:
            # Check if confirmation needed
            if needs_confirmation:
                if alternatives:
                    # Multiple similar locations found
                    print(f"⚠️ Ambiguous location - {len(alternatives)} alternatives found")
                    
                    # Ask for clarification
                    dialogue.trigger_location_confirmation(alternatives)
                    
                    # Present options
                    options_text = "I found multiple similar locations. Please tell me which one: "
                    for i, alt in enumerate(alternatives[:3], 1):
                        options_text += f"Option {i}: {alt['name'].title()}. "
                    
                    voice_out.speak(options_text)
                    
                    # Listen for clarification
                    success, clarification = voice_in.listen(timeout=10)
                    if success and clarification:
                        dialogue._handle_location_confirmation(clarification, parser)
                        
                        # Get final location
                        final_location = dialogue.get_summary()['location']
                        if final_location:
                            # Try geocoding again with confirmed location
                            location_data, _, _ = location_service.get_coordinates_with_confirmation(
                                final_location,
                                voice_out
                            )
                else:
                    # Single location but lower confidence
                    confidence = location_result.get('confidence', 0)
                    location_name = location_result['formatted_address']
                    
                    voice_out.speak(f"I found your location as {location_name}. Is this correct?")
                    
                    success, confirmation = voice_in.listen(timeout=5)
                    if success:
                        yes_no = parser.detect_yes_no(confirmation)
                        
                        if yes_no == True:
                            location_data = location_result
                            call_data['location_confirmed'] = True
                            voice_out.speak("Location confirmed.")
                        elif yes_no == False:
                            # Ask for general area
                            voice_out.speak("Please tell me the general area or major landmark nearby.")
                            success, new_location = voice_in.listen(timeout=10)
                            if success and new_location:
                                call_data['location'] = new_location
                                location_data, _, _ = location_service.get_coordinates_with_confirmation(
                                    new_location,
                                    voice_out
                                )
                        else:
                            # Unclear, proceed with original
                            location_data = location_result
            else:
                # High confidence, no confirmation needed
                location_data = location_result
                print(f"✅ High confidence match ({location_result.get('confidence', 0):.1f}%)")
        
        # If still no location data, ask for general area
        if not location_data:
            voice_out.speak("I couldn't find your exact location. Can you tell me the nearest major area, like the city or main road?")
            success, general_area = voice_in.listen(timeout=10)
            if success and general_area:
                call_data['location'] = general_area
                location_data, _, _ = location_service.get_coordinates_with_confirmation(
                    general_area,
                    voice_out
                )
    
    # ============================================================================
    # END OF ENHANCED LOCATION PROCESSING CODE
    # ============================================================================
    
    # ML classification if needed
    if call_data['emergency_type'] == 'unknown' and ml_classifier.is_trained:
        description = call_data.get('description', '')
        if description:
            ml_type, confidence = ml_classifier.predict(description)
            if confidence > 0.5:
                call_data['emergency_type'] = ml_type
                call_data['confidence'] = confidence
                print(f"🤖 ML classified as: {ml_type} (confidence: {confidence:.2%})")
    
    # Save to database
    call_id = db.save_call(call_data, location_data)
    
    # Enhanced Summary
    print("\n" + "=" * 70)
    print("📋 ENHANCED CALL SUMMARY")
    print("=" * 70)
    print(f"Call ID: {call_id}")
    print(f"Emergency Type: {call_data['emergency_type'].upper()}")
    print(f"Urgency Level: {call_data['urgency_level'].upper()}")
    print(f"Distress Score: {call_data['distress_score']:.2f}/1.0")
    
    if call_data['symptoms']:
        print(f"Symptoms: {', '.join(call_data['symptoms'])}")
    
    print(f"\nLocation (text): {call_data['location']}")
    
    if location_data:
        print(f"📍 GPS Coordinates: {location_data['latitude']:.4f}, {location_data['longitude']:.4f}")
        print(f"📍 Full Address: {location_data['formatted_address']}")
        print(f"✅ Within Service: {location_data['within_service_area']}")
    
    print(f"\nInjuries: {'Yes' if call_data['injuries'] else 'No'}")
    if call_data['injury_count']:
        print(f"Number Injured: {call_data['injury_count']} people")
    
    print(f"Currently Safe: {'Yes' if call_data['is_safe'] else 'No'}")
    print(f"Description: {call_data['description']}")
    
    if call_data['keywords']:
        print(f"Keywords: {', '.join(call_data['keywords'][:8])}")
    
    # Dispatch ambulance
    if location_data:
        # Mock ambulance list
        mock_ambulances = [
            {'id': 'AMB001', 'lat': 12.9500, 'lng': 77.5800},
            {'id': 'AMB002', 'lat': 12.9800, 'lng': 77.6000},
            {'id': 'AMB003', 'lat': 12.9300, 'lng': 77.6200},
        ]
        
        nearest = location_service.find_nearest_ambulance(
            location_data['latitude'],
            location_data['longitude'],
            mock_ambulances
        )
        
        if nearest:
            print(f"\n🚨 AMBULANCE DISPATCH")
            print(f"   Ambulance ID: {nearest['id']}")
            print(f"   Distance: {nearest['distance_km']} km")
            print(f"   ETA: {nearest['eta_minutes']} minutes")
            
            # Update database
            db.update_ambulance_dispatch(call_id, nearest['id'], int(nearest['eta_minutes']))
            
            # Speak appropriate message based on urgency
            if call_data['urgency_level'] == 'critical':
                voice_out.speak(f"Critical emergency. Ambulance {nearest['id']} is rushing to your location. Expected arrival in {int(nearest['eta_minutes'])} minutes. Stay calm.")
            elif call_data['urgency_level'] == 'urgent':
                voice_out.speak(f"Help is on the way. Ambulance arriving in approximately {int(nearest['eta_minutes'])} minutes.")
            else:
                voice_out.speak(f"Ambulance has been dispatched. Estimated arrival time is {int(nearest['eta_minutes'])} minutes.")
    else:
        print("\n⚠️ Location not found. Manual dispatch required.")
        voice_out.speak("We couldn't locate you automatically. Our team will call you back shortly.")
    
    print("\n" + "=" * 70)
    print("✅ Emergency call processing complete")
    print("=" * 70)

if __name__ == "__main__":
    # Create necessary directories
    os.makedirs('data', exist_ok=True)
    os.makedirs('models', exist_ok=True)
    main()
