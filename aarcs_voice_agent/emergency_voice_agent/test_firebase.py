# test_firebase.py
from scripts.firebase_client import FirebaseClient
import time

print("Testing Firebase connection...")
firebase = FirebaseClient()

if firebase.initialized:
    print("✅ Firebase initialized successfully")
    
    # Start a test call
    call_id = firebase.start_call()
    if call_id:
        print(f"✅ Test call started with ID: {call_id}")
        
        # Log a test message
        firebase.log_message('agent', "This is a test message from NLP agent")
        firebase.log_message('user', "This is a test response")
        
        print("✅ Test messages sent to Firebase")
        print("Check your dashboard to see if messages appear")
        
        # Wait a bit then end the call
        time.sleep(2)
        
        # Create a test summary
        test_summary = {
            'timestamp': time.time(),
            'emergency_info': {
                'type': 'test',
                'location': 'Test Location',
                'urgency': 'normal'
            },
            'call_summary': {
                'emergency_type': 'test',
                'location': 'Test Location',
                'duration': '0:00:10',
                'questions_asked': 2,
                'injuries': False,
                'is_safe': True
            }
        }
        
        firebase.end_call(test_summary)
        print("✅ Test call ended with summary")
    else:
        print("❌ Failed to start test call")
else:
    print("❌ Firebase not initialized. Check serviceAccountKey.json location")