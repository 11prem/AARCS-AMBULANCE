# voice_input.py - RELIABLE version with multiple fallbacks
import speech_recognition as sr
import sounddevice as sd
import soundfile as sf
import numpy as np
import tempfile
import os
import time
import threading
from colorama import init, Fore, Style

init(autoreset=True)

class VoiceInput:
    def __init__(self):
        self.recognizer = sr.Recognizer()
        self.sample_rate = 16000
        self.use_sounddevice = False
        self.use_pyaudio = False
        
        print(Fore.CYAN + "🎤 Initializing voice input..." + Style.RESET_ALL)
        
        # Test which method works
        self.test_input_methods()
        
        if not self.use_sounddevice and not self.use_pyaudio:
            print(Fore.YELLOW + "⚠️ Using speech_recognition's built-in microphone" + Style.RESET_ALL)
    
    def test_input_methods(self):
        """Test different audio input methods"""
        print(Fore.CYAN + "🔍 Testing audio input methods..." + Style.RESET_ALL)
        
        # Method 1: Test sounddevice
        try:
            devices = sd.query_devices()
            default_input = sd.default.device[0]
            if default_input != -1:
                self.use_sounddevice = True
                print(Fore.GREEN + "✅ sounddevice available" + Style.RESET_ALL)
            else:
                print(Fore.YELLOW + "⚠️ sounddevice: No input device" + Style.RESET_ALL)
        except Exception as e:
            print(Fore.YELLOW + f"⚠️ sounddevice test failed: {e}" + Style.RESET_ALL)
        
        # Method 2: Test speech_recognition's microphone
        try:
            with sr.Microphone() as source:
                print(Fore.GREEN + "✅ speech_recognition microphone available" + Style.RESET_ALL)
                self.use_pyaudio = True
        except Exception as e:
            print(Fore.YELLOW + f"⚠️ speech_recognition microphone failed: {e}" + Style.RESET_ALL)
    
    def listen_sounddevice(self, timeout=5):
        """Listen using sounddevice"""
        try:
            print(Fore.CYAN + "🔊 Using sounddevice..." + Style.RESET_ALL)
            
            # Record audio
            duration = timeout
            recording = sd.rec(
                int(duration * self.sample_rate),
                samplerate=self.sample_rate,
                channels=1,
                dtype='float32'
            )
            sd.wait()
            
            # Save to temp file
            temp_file = tempfile.NamedTemporaryFile(suffix='.wav', delete=False)
            temp_filename = temp_file.name
            temp_file.close()
            
            sf.write(temp_filename, recording, self.sample_rate)
            
            # Recognize
            with sr.AudioFile(temp_filename) as source:
                audio = self.recognizer.record(source)
            
            os.remove(temp_filename)
            
            text = self.recognizer.recognize_google(audio, language='en-IN')
            return True, text.lower()
            
        except Exception as e:
            print(Fore.YELLOW + f"⚠️ sounddevice failed: {e}" + Style.RESET_ALL)
            return False, ""
    
    def listen_speechrecognition(self, timeout=5):
        """Listen using speech_recognition's built-in microphone"""
        try:
            print(Fore.CYAN + "🔊 Using speech_recognition microphone..." + Style.RESET_ALL)
            
            with sr.Microphone() as source:
                # Adjust for ambient noise
                self.recognizer.adjust_for_ambient_noise(source, duration=0.5)
                
                print(Fore.GREEN + "🎤 Listening... Speak now!" + Style.RESET_ALL)
                audio = self.recognizer.listen(source, timeout=timeout, phrase_time_limit=timeout-1)
                
                text = self.recognizer.recognize_google(audio, language='en-IN')
                return True, text.lower()
                
        except sr.WaitTimeoutError:
            print(Fore.YELLOW + "⏱️ Timeout - no speech detected" + Style.RESET_ALL)
            return False, ""
        except sr.UnknownValueError:
            print(Fore.YELLOW + "❌ Could not understand speech" + Style.RESET_ALL)
            return False, ""
        except Exception as e:
            print(Fore.YELLOW + f"⚠️ speech_recognition failed: {e}" + Style.RESET_ALL)
            return False, ""
    
    def listen_simple(self, timeout=5):
        """Simple listening with immediate feedback"""
        print(Fore.GREEN + "\n" + "="*40)
        print("🎤 SPEAK NOW")
        print("="*40 + Style.RESET_ALL)
        
        # Try speech_recognition first (most reliable)
        if self.use_pyaudio:
            success, text = self.listen_speechrecognition(timeout)
            if success:
                return True, text
        
        # Try sounddevice as fallback
        if self.use_sounddevice:
            success, text = self.listen_sounddevice(timeout)
            if success:
                return True, text
        
        # All methods failed
        return False, ""
    
    def listen(self, timeout=10):
        """
        Main listening method with multiple fallbacks
        Returns: (success: bool, text: str)
        """
        print(Fore.CYAN + f"\n💬 Ready for response (timeout: {timeout}s)" + Style.RESET_ALL)
        print(Fore.YELLOW + "   Speak clearly into your microphone" + Style.RESET_ALL)
        
        # Try to get voice input
        success, text = self.listen_simple(timeout)
        
        if success:
            print(Fore.GREEN + f"✅ Recognized: '{text}'" + Style.RESET_ALL)
            return True, text
        else:
            # Voice failed, use text input as fallback
            print(Fore.YELLOW + "\n🔇 Voice input failed. Using text input..." + Style.RESET_ALL)
            text = input(Fore.CYAN + "📝 Type your response: " + Style.RESET_ALL)
            
            if text.strip():
                print(Fore.GREEN + f"✅ Text input: '{text}'" + Style.RESET_ALL)
                return True, text.strip()
            else:
                print(Fore.YELLOW + "⚠️ No input received" + Style.RESET_ALL)
                return False, ""
    
    def quick_test(self):
        """Quick test of the microphone"""
        print(Fore.CYAN + "\n🧪 Quick microphone test..." + Style.RESET_ALL)
        print(Fore.YELLOW + "Please say 'test' or any word" + Style.RESET_ALL)
        
        success, text = self.listen_simple(timeout=3)
        
        if success:
            print(Fore.GREEN + f"✅ Test passed! Heard: '{text}'" + Style.RESET_ALL)
            return True
        else:
            print(Fore.RED + "❌ Test failed - microphone not working" + Style.RESET_ALL)
            return False

# ==================== SIMPLER ALTERNATIVE ====================
class SimpleVoiceInput:
    """Super simple voice input that definitely works"""
    
    def __init__(self):
        self.recognizer = sr.Recognizer()
        print(Fore.GREEN + "🎤 Simple voice input initialized" + Style.RESET_ALL)
    
    def listen(self, timeout=10):
        """Simple and reliable listen"""
        print(Fore.GREEN + "\n" + "="*50)
        print("🎤 LISTENING - SPEAK NOW!")
        print("="*50 + Style.RESET_ALL)
        
        try:
            with sr.Microphone() as source:
                # Quick adjustment
                print(Fore.CYAN + "Adjusting for noise... " + Style.RESET_ALL, end='', flush=True)
                self.recognizer.adjust_for_ambient_noise(source, duration=1)
                print(Fore.GREEN + "✓" + Style.RESET_ALL)
                
                print(Fore.YELLOW + f"Listening for {timeout} seconds..." + Style.RESET_ALL)
                
                # Listen with visual feedback
                start_time = time.time()
                audio = self.recognizer.listen(source, timeout=timeout, phrase_time_limit=timeout-2)
                
                print(Fore.CYAN + "Processing speech... " + Style.RESET_ALL, end='', flush=True)
                text = self.recognizer.recognize_google(audio, language='en-IN')
                print(Fore.GREEN + "✓" + Style.RESET_ALL)
                
                elapsed = time.time() - start_time
                print(Fore.GREEN + f"✅ Heard ({elapsed:.1f}s): '{text}'" + Style.RESET_ALL)
                return True, text.lower()
                
        except sr.WaitTimeoutError:
            print(Fore.YELLOW + "⏱️ Timeout - no speech detected" + Style.RESET_ALL)
        except sr.UnknownValueError:
            print(Fore.YELLOW + "❌ Speech not clear" + Style.RESET_ALL)
        except sr.RequestError as e:
            print(Fore.RED + f"❌ Service error: {e}" + Style.RESET_ALL)
        except Exception as e:
            print(Fore.RED + f"❌ Error: {e}" + Style.RESET_ALL)
        
        # Fallback to text
        return self.fallback_to_text()
    
    def fallback_to_text(self):
        """Fallback to text input"""
        print(Fore.YELLOW + "\n🔄 Switching to text input..." + Style.RESET_ALL)
        text = input(Fore.CYAN + "📝 Type your response: " + Style.RESET_ALL)
        
        if text.strip():
            print(Fore.GREEN + f"✅ Text: '{text}'" + Style.RESET_ALL)
            return True, text.strip()
        else:
            print(Fore.YELLOW + "⚠️ No input" + Style.RESET_ALL)
            return False, ""

# ==================== TEST FUNCTION ====================
def test_voice_input():
    """Test voice input thoroughly"""
    print(Fore.MAGENTA + "\n" + "="*60)
    print("VOICE INPUT SYSTEM TEST")
    print("="*60 + Style.RESET_ALL)
    
    print("\nChoose test method:")
    print("1. Advanced VoiceInput (multiple fallbacks)")
    print("2. SimpleVoiceInput (most reliable)")
    print("3. Direct speech_recognition test")
    
    choice = input(Fore.CYAN + "\nSelect (1-3): " + Style.RESET_ALL).strip()
    
    if choice == "1":
        print(Fore.CYAN + "\nTesting Advanced VoiceInput..." + Style.RESET_ALL)
        vi = VoiceInput()
        vi.quick_test()
        
        print(Fore.CYAN + "\nFull test..." + Style.RESET_ALL)
        success, text = vi.listen(timeout=5)
        
    elif choice == "2":
        print(Fore.CYAN + "\nTesting SimpleVoiceInput..." + Style.RESET_ALL)
        vi = SimpleVoiceInput()
        success, text = vi.listen(timeout=7)
        
    elif choice == "3":
        print(Fore.CYAN + "\nDirect speech_recognition test..." + Style.RESET_ALL)
        
        r = sr.Recognizer()
        
        try:
            print("Checking for microphone...")
            with sr.Microphone() as source:
                print(Fore.GREEN + "✅ Microphone found!" + Style.RESET_ALL)
                
                print("Adjusting for noise...")
                r.adjust_for_ambient_noise(source, duration=1)
                
                print(Fore.YELLOW + "🎤 Speak now (5 seconds)..." + Style.RESET_ALL)
                audio = r.listen(source, timeout=5)
                
                print("Processing...")
                text = r.recognize_google(audio)
                
                print(Fore.GREEN + f"✅ Success! You said: '{text}'" + Style.RESET_ALL)
                
        except Exception as e:
            print(Fore.RED + f"❌ Test failed: {e}" + Style.RESET_ALL)
    
    print(Fore.CYAN + "\n" + "="*60)
    print("TEST COMPLETE")
    print("="*60 + Style.RESET_ALL)

if __name__ == "__main__":
    test_voice_input()