# voice_debug.py - Diagnostic tool for voice input issues
import os
import sys
import time
from datetime import datetime

print("🔍 VOICE INPUT DIAGNOSTIC TOOL")
print("=" * 60)

# Test 1: Check Python and System
print("\n1️⃣ CHECKING PYTHON AND SYSTEM...")
print(f"Python version: {sys.version}")
print(f"Current directory: {os.getcwd()}")
print(f"Platform: {sys.platform}")

# Test 2: Check if required packages are installed
print("\n2️⃣ CHECKING REQUIRED PACKAGES...")
required_packages = [
    'speechrecognition',
    'pyaudio',
    'pyttsx3',
    'sounddevice',
    'soundfile',
    'scipy'
]

for package in required_packages:
    try:
        __import__(package)
        print(f"✅ {package} is installed")
    except ImportError:
        print(f"❌ {package} is NOT installed")

# Test 3: Check microphone access
print("\n3️⃣ CHECKING MICROPHONE ACCESS...")
try:
    import speech_recognition as sr
    r = sr.Recognizer()
    
    # List available microphones
    print("Available microphones:")
    mic_list = sr.Microphone.list_microphone_names()
    if mic_list:
        for i, mic_name in enumerate(mic_list):
            print(f"  [{i}] {mic_name}")
    else:
        print("  No microphones detected!")
    
    # Test microphone
    try:
        with sr.Microphone() as source:
            print("✅ Microphone object created successfully")
            print(f"  Sample rate: {source.SAMPLE_RATE}")
            print(f"  Chunk size: {source.CHUNK}")
    except Exception as e:
        print(f"❌ Microphone access error: {e}")
        
except Exception as e:
    print(f"❌ SpeechRecognition error: {e}")

# Test 4: Try basic voice recording
print("\n4️⃣ TESTING BASIC VOICE RECORDING...")
try:
    import speech_recognition as sr
    r = sr.Recognizer()
    
    print("🎤 Attempting to record audio (5 seconds)...")
    print("   Speak something now...")
    
    with sr.Microphone() as source:
        # Adjust for ambient noise
        print("   Adjusting for ambient noise...")
        r.adjust_for_ambient_noise(source, duration=1)
        
        # Record audio
        print("   Recording...")
        audio = r.listen(source, timeout=5, phrase_time_limit=5)
        print("✅ Audio recorded successfully!")
        
        # Try to recognize
        print("   Processing speech...")
        try:
            text = r.recognize_google(audio)
            print(f"✅ Speech recognized: '{text}'")
        except sr.UnknownValueError:
            print("❌ Could not understand audio")
        except sr.RequestError as e:
            print(f"❌ Google API error: {e}")
            
except Exception as e:
    print(f"❌ Recording test failed: {e}")

# Test 5: Test PyAudio directly
print("\n5️⃣ TESTING PYAUDIO DIRECTLY...")
try:
    import pyaudio
    
    p = pyaudio.PyAudio()
    print(f"✅ PyAudio initialized (version: {pyaudio.__version__})")
    
    # Get device info
    info = p.get_host_api_info_by_index(0)
    num_devices = info.get('deviceCount')
    print(f"  Found {num_devices} audio devices")
    
    for i in range(num_devices):
        try:
            device_info = p.get_device_info_by_host_api_device_index(0, i)
            device_name = device_info.get('name')
            max_input_channels = device_info.get('maxInputChannels')
            if max_input_channels > 0:
                print(f"  Input Device {i}: {device_name}")
        except:
            pass
    
    p.terminate()
    
except ImportError:
    print("❌ PyAudio not installed")
except Exception as e:
    print(f"❌ PyAudio test error: {e}")

# Test 6: Check alternative recording method
print("\n6️⃣ TESTING ALTERNATIVE RECORDING METHOD...")
try:
    import sounddevice as sd
    import soundfile as sf
    
    # Get device list
    print("SoundDevice devices:")
    devices = sd.query_devices()
    for i, device in enumerate(devices):
        if device['max_input_channels'] > 0:
            print(f"  Input Device {i}: {device['name']}")
    
    # Test recording
    print("  Testing 2-second recording...")
    duration = 2
    fs = 44100
    recording = sd.rec(int(duration * fs), samplerate=fs, channels=1)
    print("  Speak now...")
    sd.wait()
    print("✅ Recording complete")
    
except ImportError:
    print("❌ SoundDevice not installed")
except Exception as e:
    print(f"❌ SoundDevice test error: {e}")

# Test 7: System permissions
print("\n7️⃣ SYSTEM PERMISSIONS CHECK...")
if sys.platform == "darwin":  # macOS
    print("macOS detected - check System Preferences > Security & Privacy > Microphone")
elif sys.platform == "win32":  # Windows
    print("Windows detected - check Settings > Privacy > Microphone")
elif sys.platform.startswith("linux"):  # Linux
    print("Linux detected - check pulseaudio permissions")
    print("  Try: sudo apt-get install pulseaudio python3-pyaudio")
else:
    print(f"Unknown platform: {sys.platform}")

print("\n" + "=" * 60)
print("🎯 TROUBLESHOOTING STEPS:")
print("1. If packages missing: pip install -r requirements.txt")
print("2. If microphone not found: check physical connection")
print("3. If permissions error: check system microphone settings")
print("4. If still issues, try: pip install --upgrade pyaudio")
print("=" * 60)

# Test 8: Quick fix installation
print("\n📦 QUICK FIX - ATTEMPTING TO INSTALL MISSING PACKAGES...")
import subprocess
import importlib

def install_package(package):
    """Install a package using pip"""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        return True
    except:
        return False

# Check and install missing packages
for package in required_packages:
    try:
        importlib.import_module(package)
    except ImportError:
        print(f"Installing {package}...")
        if install_package(package):
            print(f"✅ Installed {package}")
        else:
            print(f"❌ Failed to install {package}")

print("\n✅ Diagnostic complete!")
print("Run this script again after installations to verify fixes.")