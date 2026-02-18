# debug_env.py
import os
from pathlib import Path
from dotenv import load_dotenv

print("=" * 60)
print("DEBUGGING .env FILE LOCATION")
print("=" * 60)

# Current directory
current_dir = os.getcwd()
print(f"📁 Current directory: {current_dir}")

# Check for .env in current directory
env_path = Path('.env')
print(f"📁 .env in current dir: {env_path.exists()}")

if env_path.exists():
    print("   ✅ Found .env here")
    with open('.env', 'r') as f:
        content = f.read()
        print(f"   Content: {content[:100]}...")
else:
    print("   ❌ No .env in current directory")

# Check parent directory
parent_env = Path('..') / '.env'
print(f"\n📁 .env in parent dir: {parent_env.exists()}")

if parent_env.exists():
    print("   ✅ Found .env in parent directory")
    
# Try to load .env
loaded = load_dotenv()
print(f"\n📁 load_dotenv() result: {loaded}")

# Check environment variable
creds_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
print(f"\n🔑 GOOGLE_APPLICATION_CREDENTIALS: {creds_path}")

if creds_path:
    print(f"   File exists: {os.path.exists(creds_path)}")
else:
    print("   ❌ Not set")

# Try loading with explicit path
if parent_env.exists():
    print(f"\n🔄 Trying to load from parent: {parent_env}")
    load_dotenv(parent_env)
    creds_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
    print(f"   Now GOOGLE_APPLICATION_CREDENTIALS: {creds_path}")

print("\n" + "=" * 60)