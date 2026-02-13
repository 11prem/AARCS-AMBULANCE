# simple_voice_test.py - Minimal voice test
import speech_recognition as sr
import time

def simple_voice_test():
    """Simple test without any project dependencies"""
    print("🎤 SIMPLE VOICE TEST")
    print("=" * 40)
    
    # Initialize recognizer
    r = sr.Recognizer()
    
    # Show available mics
    print("\nAvailable microphones:")
    mics = sr.Microphone.list_microphone_names()
    for i, mic in enumerate(mics):
        print(f"  [{i}] {mic}")
    
    # Try default microphone
    print("\nTrying default microphone...")
    try:
        with sr.Microphone() as source:
            print("✅ Microphone ready!")
            
            # Adjust for noise
            print("Adjusting for ambient noise... (2 seconds)")
            r.adjust_for_ambient_noise(source, duration=2)
            print("Ready!")
            
            # Record
            print("\n🎤 Speak now (I'm listening for 5 seconds)...")
            audio = r.listen(source, timeout=10, phrase_time_limit=5)
            print("✅ Audio captured!")
            
            # Recognize
            print("Processing...")
            try:
                text = r.recognize_google(audio)
                print(f"\n✅ You said: '{text}'")
                return True
            except sr.UnknownValueError:
                print("❌ Could not understand audio")
                return False
            except sr.RequestError as e:
                print(f"❌ API error: {e}")
                return False
                
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_with_specific_mic(mic_index=0):
    """Test with specific microphone index"""
    print(f"\n🔧 Testing with microphone index {mic_index}...")
    
    r = sr.Recognizer()
    
    try:
        with sr.Microphone(device_index=mic_index) as source:
            print("✅ Microphone opened!")
            
            # Quick test
            print("Speak 'hello' now...")
            audio = r.listen(source, timeout=3, phrase_time_limit=2)
            
            try:
                text = r.recognize_google(audio)
                print(f"✅ Heard: '{text}'")
                return True
            except:
                print("❌ Didn't hear anything")
                return False
                
    except Exception as e:
        print(f"❌ Error with mic {mic_index}: {e}")
        return False

if __name__ == "__main__":
    # Run simple test
    success = simple_voice_test()
    
    if not success:
        print("\n" + "=" * 40)
        print("Trying alternative microphones...")
        print("=" * 40)
        
        # List all mics
        r = sr.Recognizer()
        mics = sr.Microphone.list_microphone_names()
        
        for i in range(min(5, len(mics))):  # Try first 5 mics
            print(f"\nTesting microphone {i}: {mics[i]}")
            test_with_specific_mic(i)
            time.sleep(1)
    
    print("\n" + "=" * 40)
    print("TEST COMPLETE")