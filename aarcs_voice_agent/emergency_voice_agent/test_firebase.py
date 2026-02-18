# test_firebase.py - Updated with proper summary generation
from scripts.firebase_client import FirebaseClient
import time
from datetime import datetime
import json  # <-- ADD THIS IMPORT

print("=" * 60)
print("TESTING FIREBASE WITH PROPER SUMMARY")
print("=" * 60)

# Initialize Firebase
firebase = FirebaseClient()

if not firebase.initialized:
    print("❌ Firebase not initialized. Exiting.")
    exit(1)

# Start a call
print("\n1️⃣ Starting call...")
call_id = firebase.start_call()

if not call_id:
    print("❌ Failed to start call")
    exit(1)

print(f"✅ Call started with ID: {call_id}")

# Send test messages (simulating a real call)
print("\n2️⃣ Simulating emergency call conversation...")

test_messages = [
    ("agent", "Hello, this is 108 emergency service. What's your emergency?"),
    ("user", "There's been a car accident near City Mall"),
    ("agent", "How many people are involved and are there any injuries?"),
    ("user", "Two people, both are conscious but one has bleeding from the head"),
    ("agent", "Where exactly is the location? What's the nearest landmark?"),
    ("user", "Near the main entrance of City Mall, on the service road"),
    ("agent", "Is anyone trapped in the vehicles?"),
    ("user", "No, everyone is out of the cars"),
    ("agent", "Is the scene safe? Any fire or smoke?"),
    ("user", "No fire, but traffic is building up")
]

start_time = datetime.now()
question_count = 0

for i, (speaker, message) in enumerate(test_messages, 1):
    print(f"\n   [{speaker.upper()}] {message}")
    firebase.log_message(speaker, message)
    if speaker == 'agent':
        question_count += 1
    time.sleep(1.5)  # Simulate real conversation pacing

call_duration = datetime.now() - start_time

print("\n3️⃣ Generating call summary...")

# Create mock data structures
call_data = {
    'emergency_type': 'accident',
    'location': 'Near City Mall, service road',
    'urgency_level': 'high',
    'description': 'Car accident with two injured, one with head bleeding',
    'injuries': True,
    'injury_count': 2,
    'is_safe': True
}

location_data = {
    'formatted_address': 'City Mall, Service Road, Mumbai',
    'latitude': 19.0760,
    'longitude': 72.8777,
    'within_service_area': True
}

ambulance_info = {
    'id': 'AMB-108-001',
    'distance_km': 3.5,
    'eta_minutes': 8,
    'speed_kmh': 45
}

# Generate summary using the Firebase client
summary = firebase.generate_summary(
    call_data=call_data,
    location_data=location_data,
    ambulance_info=ambulance_info,
    call_db_id=12345,
    call_start_time=start_time,
    call_duration=call_duration,
    question_count=question_count
)

print("\n📋 Generated Summary:")
print(json.dumps(summary, indent=2)[:500] + "...")  # Print first 500 chars

# End call with summary
print("\n4️⃣ Ending call and saving summary...")
firebase.end_call(summary)

print("\n✅ Test complete!")
print("Check your dashboard - the summary box should now appear with all the call details!")