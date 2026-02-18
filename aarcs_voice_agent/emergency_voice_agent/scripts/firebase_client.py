# firebase_client.py - Complete version with all methods
import firebase_admin
from firebase_admin import credentials, db
import os
import json
from datetime import datetime
import uuid
import time
from pathlib import Path
from dotenv import load_dotenv

# Try to load .env from multiple possible locations
env_paths = [
    Path('.env'),  # current directory
    Path('..') / '.env',  # parent directory
    Path('..') / '..' / '.env',  # two levels up (project root)
]

for env_path in env_paths:
    if env_path.exists():
        print(f"📁 Loading .env from: {env_path}")
        load_dotenv(env_path)
        break

class FirebaseClient:
    """Client to push real-time data to Firebase dashboard"""
    
    def __init__(self):
        """Initialize Firebase Admin SDK"""
        self.initialized = False
        self.current_call_id = None
        self.app = None
        self.conversation = []  # Track full conversation for summary
        
        try:
            # Get the path from environment
            key_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
            print(f"🔍 DEBUG - Key path from env: {key_path}")
            
            if key_path and os.path.exists(key_path):
                print(f"📁 Key file EXISTS at: {key_path}")
                print(f"📁 File size: {os.path.getsize(key_path)} bytes")
                cred = credentials.Certificate(key_path)
            else:
                print(f"❌ Key file NOT FOUND at: {key_path}")
                print(f"   Current working directory: {os.getcwd()}")
                return
            
            # Get database URL from environment or use default
            database_url = os.environ.get(
                'FIREBASE_DATABASE_URL', 
                'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app'
            )
            print(f"🔍 Database URL: {database_url}")
            
            # Initialize with explicit database URL
            self.app = firebase_admin.initialize_app(cred, {
                'databaseURL': database_url
            })
            self.initialized = True
            print("✅ Firebase Admin initialized successfully")
            
            # Test the connection
            try:
                ref = db.reference('/')
                ref.get()
                print("✅ Firebase connection test successful")
                
                # Test write permission
                test_ref = db.reference('_connection_test')
                test_ref.set({'timestamp': int(time.time() * 1000), 'status': 'ok'})
                print("✅ Firebase write test successful")
                test_ref.delete()
                
            except Exception as e:
                print(f"⚠️ Firebase connection test failed: {e}")
                
        except Exception as e:
            print(f"❌ Firebase initialization error: {e}")
            import traceback
            traceback.print_exc()
    
    def start_call(self):
        """Start a new call and get a call ID"""
        if not self.initialized:
            print("⚠️ Firebase not initialized, cannot start call")
            return None
            
        try:
            self.current_call_id = str(uuid.uuid4())[:8]  # Short ID for readability
            self.conversation = []  # Reset conversation for new call
            timestamp = int(time.time() * 1000)  # Milliseconds for JS
            
            call_data = {
                'callId': self.current_call_id,
                'timestamp': timestamp,
                'status': 'active',
                'startTime': datetime.now().isoformat()
            }
            
            print(f"📤 Writing to Firebase: live_calls/{self.current_call_id}")
            
            # Write to Firebase
            ref = db.reference(f'live_calls/{self.current_call_id}')
            ref.set(call_data)
            
            # Verify it was written
            verification = ref.get()
            if verification:
                print(f"✅ Call started successfully in Firebase: {self.current_call_id}")
                print(f"   Data written: {verification}")
            else:
                print(f"⚠️ Call data written but verification failed")
            
            return self.current_call_id
            
        except Exception as e:
            print(f"❌ Error starting call in Firebase: {e}")
            import traceback
            traceback.print_exc()
            return None
    
    def log_message(self, speaker, message):
        """Log a single message to the current call"""
        if not self.initialized:
            print("⚠️ Firebase not initialized, cannot log message")
            return False
            
        if not self.current_call_id:
            print("⚠️ No active call, cannot log message")
            return False
            
        try:
            timestamp = int(time.time() * 1000)
            message_id = str(uuid.uuid4())[:8]
            time_str = datetime.now().strftime('%H:%M:%S')
            
            message_data = {
                'speaker': speaker,  # 'agent' or 'user'
                'message': message,
                'timestamp': timestamp,
                'time': time_str
            }
            
            # Store in local conversation list for summary
            self.conversation.append({
                'speaker': speaker,
                'message': message,
                'time': time_str,
                'timestamp': timestamp
            })
            
            print(f"📤 Writing message to: live_calls/{self.current_call_id}/messages/{message_id}")
            print(f"   Message: [{speaker}] {message[:50]}...")
            
            # Push to messages node
            ref = db.reference(f'live_calls/{self.current_call_id}/messages/{message_id}')
            ref.set(message_data)
            
            # Verify
            verification = ref.get()
            if verification:
                print(f"✅ Message verified in Firebase")
            else:
                print(f"⚠️ Message verification failed")
            
            return True
            
        except Exception as e:
            print(f"❌ Error logging message: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def generate_summary(self, call_data, location_data, ambulance_info, call_db_id, call_start_time, call_duration, question_count):
        """Generate a comprehensive summary from the call data"""
        
        # Build conversation from stored messages
        conversation_log = []
        for msg in self.conversation:
            conversation_log.append({
                'time': msg['time'],
                'speaker': 'ai' if msg['speaker'] == 'agent' else 'user',
                'message': msg['message']
            })
        
        # Build emergency info
        emergency_info = {
            'type': call_data.get('emergency_type', 'unknown'),
            'location': call_data.get('location', 'Unknown'),
            'urgency': call_data.get('urgency_level', 'normal'),
            'description': call_data.get('description', ''),
            'injuries': call_data.get('injuries', False),
            'location_details': None
        }
        
        if location_data:
            emergency_info['location_details'] = {
                'address': location_data.get('formatted_address', ''),
                'latitude': location_data.get('latitude', 0),
                'longitude': location_data.get('longitude', 0),
                'in_service_area': location_data.get('within_service_area', False)
            }
        
        # Build ambulance data
        ambulance_data = {}
        if ambulance_info:
            ambulance_data = {
                'id': ambulance_info.get('id', ''),
                'status': 'dispatched',
                'distance_km': ambulance_info.get('distance_km', 0),
                'eta_minutes': ambulance_info.get('eta_minutes', 0)
            }
        
        # Build call summary
        call_summary = {
            'emergency_type': call_data.get('emergency_type', 'unknown'),
            'location': call_data.get('location', 'Unknown'),
            'duration': str(call_duration),
            'questions_asked': question_count,
            'injuries': call_data.get('injuries', False),
            'injury_count': call_data.get('injury_count', None),
            'is_safe': call_data.get('is_safe', None),
            'urgency': call_data.get('urgency_level', 'normal'),
            'call_id': call_db_id,
            'timestamp': call_start_time.strftime("%Y-%m-%d %H:%M:%S"),
            'status': 'completed'
        }
        
        if location_data:
            call_summary['location_details'] = {
                'address': location_data.get('formatted_address', ''),
                'coordinates': f"{location_data.get('latitude', 0):.4f}, {location_data.get('longitude', 0):.4f}"
            }
        
        # Complete summary
        complete_summary = {
            'timestamp': datetime.now().isoformat(),
            'emergency_info': emergency_info,
            'ambulance_data': ambulance_data,
            'conversation': conversation_log,
            'call_summary': call_summary,
            'call_duration': str(call_duration)
        }
        
        return complete_summary
    
    def end_call(self, summary_data):
        """End the current call and save summary"""
        if not self.initialized or not self.current_call_id:
            print("⚠️ Cannot end call - not initialized or no active call")
            return False
            
        try:
            timestamp = int(time.time() * 1000)
            
            print(f"📤 Updating call status to completed")
            
            # Update call status
            ref = db.reference(f'live_calls/{self.current_call_id}')
            ref.update({
                'status': 'completed',
                'endTime': datetime.now().isoformat()
            })
            
            # Save summary to a separate node
            print(f"📤 Saving summary to: call_summaries/{self.current_call_id}")
            summary_ref = db.reference(f'call_summaries/{self.current_call_id}')
            summary_ref.set(summary_data)
            
            print(f"✅ Call ended and summary saved: {self.current_call_id}")
            
            # Save local copy for debugging
            try:
                os.makedirs('call_summaries', exist_ok=True)
                filename = f"call_summaries/summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
                with open(filename, 'w') as f:
                    json.dump(summary_data, f, indent=2)
                print(f"📁 Local summary saved to: {filename}")
            except Exception as e:
                print(f"⚠️ Could not save local summary: {e}")
            
            self.current_call_id = None
            self.conversation = []
            return True
            
        except Exception as e:
            print(f"❌ Error ending call: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def update_emergency_info(self, info_type, data):
        """Update emergency information in real-time"""
        if not self.initialized or not self.current_call_id:
            return False
            
        try:
            ref = db.reference(f'live_calls/{self.current_call_id}/emergency_info/{info_type}')
            ref.set({
                'value': data,
                'timestamp': int(time.time() * 1000)
            })
            print(f"✅ Updated emergency info: {info_type} = {data}")
            return True
        except Exception as e:
            print(f"⚠️ Error updating emergency info: {e}")
            return False