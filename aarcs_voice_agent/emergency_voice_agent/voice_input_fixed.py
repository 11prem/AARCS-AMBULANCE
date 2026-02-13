# voice_input_fixed.py - Enhanced voice input with better settings
import speech_recognition as sr
import time
import threading

class ReliableVoiceInput:
    """Enhanced voice input with better defaults and error handling"""
    
    def __init__(self, energy_threshold=300, timeout=15, phrase_time_limit=10):
        self.recognizer = sr.Recognizer()
        self.energy_threshold = energy_threshold  # Lower = more sensitive
        self.timeout = timeout
        self.phrase_time_limit = phrase_time_limit
        
        # List available microphones
        print("🔍 Available microphones:")
        mic_list = sr.Microphone.list_microphone_names()
        for i, mic in enumerate(mic_list):
            print(f"  [{i}] {mic}")
        
        # Auto-select the best microphone
        self.mic_index = self._select_best_microphone(mic_list)
        
    def _select_best_microphone(self, mic_list):
        """Try to select the best microphone automatically"""
        preferred_keywords = ['headset', 'headphone', 'mic', 'array', 'input']
        
        for i, mic_name in enumerate(mic_list):
            mic_lower = mic_name.lower()
            # Check for preferred microphones
            for keyword in preferred_keywords:
                if keyword in mic_lower and 'output' not in mic_lower:
                    print(f"✅ Selected microphone [{i}]: {mic_name}")
                    return i
        
        # Fallback to first input mic
        print(f"⚠️ Using default microphone [0]: {mic_list[0]}")
        return 0
    
    def listen(self, timeout=None, phrase_time_limit=None):
        """Enhanced listen method with better error handling"""
        if timeout is None:
            timeout = self.timeout
        if phrase_time_limit is None:
            phrase_time_limit = self.phrase_time_limit
        
        try:
            with sr.Microphone(device_index=self.mic_index) as source:
                print(f"🎤 Using microphone: {sr.Microphone.list_microphone_names()[self.mic_index]}")
                
                # Dynamic energy adjustment (much better than adjust_for_ambient_noise)
                self.recognizer.dynamic_energy_threshold = True
                self.recognizer.energy_threshold = self.energy_threshold
                
                print("   Adjusting for ambient noise (3 seconds)...")
                self.recognizer.adjust_for_ambient_noise(source, duration=3)
                print(f"   Energy threshold: {self.recognizer.energy_threshold}")
                print("   Speak now...")
                
                try:
                    audio = self.recognizer.listen(
                        source,
                        timeout=timeout,
                        phrase_time_limit=phrase_time_limit
                    )
                    
                    print("✅ Audio captured! Processing...")
                    
                    # Try Google Speech Recognition
                    text = self.recognizer.recognize_google(audio)
                    print(f"✅ Recognized: '{text}'")
                    return True, text
                    
                except sr.WaitTimeoutError:
                    print("⚠️ No speech detected within timeout")
                    return False, ""
                except sr.UnknownValueError:
                    print("⚠️ Could not understand audio")
                    return False, ""
                except sr.RequestError as e:
                    print(f"⚠️ API error: {e}")
                    return False, ""
                    
        except Exception as e:
            print(f"❌ Microphone error: {e}")
            return False, ""

# Test function
def test_voice_input():
    """Test the voice input"""
    print("🎤 TESTING ENHANCED VOICE INPUT")
    print("=" * 50)
    
    voice = ReliableVoiceInput(energy_threshold=250)  # Lower threshold = more sensitive
    
    print("\n🎤 Listening... (speak clearly)")
    success, text = voice.listen(timeout=10, phrase_time_limit=5)
    
    if success:
        print(f"\n✅ SUCCESS: You said: '{text}'")
    else:
        print("\n❌ Failed to capture audio")
    
    return success

if __name__ == "__main__":
    test_voice_input()