# firebase_client.py - Firebase integration for NLP agent
import firebase_admin
from firebase_admin import credentials, db
import os
import json
from datetime import datetime
import uuid

class FirebaseClient:
    """Client to push real-time data to Firebase dashboard"""
    
    def __init__(self):
        """Initialize Firebase Admin SDK"""
        self.initialized = False
        self.current_call_id = None
        
        try:
            # Check if already initialized
            if not firebase_admin._apps:
                # You'll need to download your service account key from Firebase Console
                # Project Settings > Service Accounts > Generate New Private Key
                # Save it as 'serviceAccountKey.json' in the project root
                
                # Try multiple possible paths for the service account key
                possible_paths = [
                    os.path.join(os.path.dirname(__file__), '..', 'serviceAccountKey.json'),
                    os.path.join(os.path.dirname(__file__), 'serviceAccountKey.json'),
                    os.path.join(os.getcwd(), 'serviceAccountKey.json'),
                ]
                
                cred_path = None
                for path in possible_paths:
                    if os.path.exists(path):
                        cred_path = path
                        break
                
                if cred_path:
                    cred = credentials.Certificate(cred_path)
                    firebase_admin.initialize_app(cred, {
                        'databaseURL': 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app'
                    })
                    self.initialized = True
                    print(f"✅ Firebase Admin initialized with credentials from {cred_path}")
                else:
                    print("⚠️ Firebase service account key not found. Call logs will not be sent to dashboard.")
                    print("   Please download serviceAccountKey.json from Firebase Console and place it in the project root.")
            else:
                self.initialized = True
                print("✅ Firebase already initialized")
                
        except Exception as e:
            print(f"⚠️ Firebase initialization error: {e}")
            print("   Call logs will not be sent to dashboard.")
    
    def start_call(self):
        """Start a new call and get a call ID"""
        if not self.initialized:
            return None
            
        try:
            self.current_call_id = str(uuid.uuid4())[:8]  # Short ID for readability
            timestamp = int(datetime.now().timestamp() * 1000)  # Milliseconds for JS
            
            call_data = {
                'callId': self.current_call_id,
                'timestamp': timestamp,
                'status': 'active',
                'startTime': datetime.now().isoformat()
            }
            
            # Write to Firebase
            ref = db.reference(f'live_calls/{self.current_call_id}')
            ref.set(call_data)
            
            print(f"📞 Call started in Firebase: {self.current_call_id}")
            return self.current_call_id
            
        except Exception as e:
            print(f"⚠️ Error starting call in Firebase: {e}")
            return None
    
    def log_message(self, speaker, message):
        """Log a single message to the current call"""
        if not self.initialized or not self.current_call_id:
            return False
            
        try:
            timestamp = int(datetime.now().timestamp() * 1000)
            message_id = str(uuid.uuid4())[:8]
            
            message_data = {
                'speaker': speaker,  # 'agent' or 'user'
                'message': message,
                'timestamp': timestamp,
                'time': datetime.now().strftime('%H:%M:%S')
            }
            
            # Push to messages node
            ref = db.reference(f'live_calls/{self.current_call_id}/messages/{message_id}')
            ref.set(message_data)
            
            print(f"📝 Logged {speaker} message: {message[:50]}...")
            return True
            
        except Exception as e:
            print(f"⚠️ Error logging message: {e}")
            return False
    
    def end_call(self, summary_data):
        """End the current call and save summary"""
        if not self.initialized or not self.current_call_id:
            return False
            
        try:
            timestamp = int(datetime.now().timestamp() * 1000)
            
            # Update call status
            ref = db.reference(f'live_calls/{self.current_call_id}')
            ref.update({
                'status': 'completed',
                'endTime': datetime.now().isoformat()
            })
            
            # Save summary to a separate node
            summary_ref = db.reference(f'call_summaries/{self.current_call_id}')
            summary_ref.set(summary_data)
            
            print(f"✅ Call ended and summary saved: {self.current_call_id}")
            self.current_call_id = None
            return True
            
        except Exception as e:
            print(f"⚠️ Error ending call: {e}")
            return False
    
    def update_emergency_info(self, info_type, data):
        """Update emergency information in real-time"""
        if not self.initialized or not self.current_call_id:
            return False
            
        try:
            ref = db.reference(f'live_calls/{self.current_call_id}/emergency_info/{info_type}')
            ref.set({
                'value': data,
                'timestamp': int(datetime.now().timestamp() * 1000)
            })
            return True
        except Exception as e:
            print(f"⚠️ Error updating emergency info: {e}")
            return False