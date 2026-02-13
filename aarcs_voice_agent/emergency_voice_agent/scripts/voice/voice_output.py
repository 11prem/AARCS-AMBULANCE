# voice_output.py - Windows SAPI (No cut-offs at all)
import win32com.client
import time

class VoiceOutput:
    def __init__(self):
        try:
            # Initialize Windows SAPI voice
            self.speaker = win32com.client.Dispatch("SAPI.SpVoice")
            
            # Configure voice settings
            self.speaker.Rate = 1  # Speed: -10 (slow) to 10 (fast)
            self.speaker.Volume = 100  # Volume: 0 to 100
            
            # Try to set female voice (Zira)
            voices = self.speaker.GetVoices()
            for i in range(voices.Count):
                voice = voices.Item(i)
                if 'zira' in voice.GetDescription().lower() or 'female' in voice.GetDescription().lower():
                    self.speaker.Voice = voice
                    print(f"🔊 Using voice: {voice.GetDescription()}")
                    break
            
            print("🔊 Voice output initialized (Windows SAPI)")
            
            # IMPORTANT: Warm up the voice engine to prevent first-word cut-off
            self.speaker.Speak(" ", 1)  # Speak empty sound asynchronously
            time.sleep(0.1)
            
        except Exception as e:
            print(f"⚠️ Error initializing voice: {e}")
            print("Make sure pywin32 is installed: pip install pywin32")
            raise
    
    def speak(self, text):
        """
        Convert text to speech and play
        NO CUT-OFFS!
        """
        print(f"🗣️ Agent: {text}")
        
        try:
            # Small delay before speaking (prevents front cut-off)
            time.sleep(0.25)
            
            # Speak the text synchronously (flag 0 = wait until complete)
            self.speaker.Speak(text, 0)
            
            # Small pause after for natural flow
            time.sleep(0.3)
            
        except Exception as e:
            print(f"⚠️ Speech error: {e}")
            print(f"📝 [Text was: {text}]")
    
    def test_voice(self):
        """Test if voice output is working without cut-offs"""
        test_phrases = [
            "What kind of emergency are you facing?",
            "Where are you located right now?",
            "Is anyone injured?",
            "Are you in a safe place?",
            "Can you describe what happened in detail?"
        ]
        
        print("\n🧪 Testing voice output for cut-offs...\n")
        for i, phrase in enumerate(test_phrases, 1):
            print(f"\n--- Test {i}/{len(test_phrases)} ---")
            self.speak(phrase)
        
        print("\n✅ Voice test complete! Check if 'What' and 'Where' were fully spoken.")
