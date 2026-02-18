# 🔥 Firebase Integration Setup for NLP Voice Agent

This guide will help your peers set up the Firebase integration for the AARCS Emergency Voice Agent on their local machines.

## 📋 Prerequisites

- Python 3.8+ installed
- Git installed
- Access to the AARCS GitHub repository
- Access to Firebase Console (project: `aarcs-2f28b`)

## 🚀 Step-by-Step Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/11prem/AARCS-AMBULANCE.git
cd AARCS-AMBULANCE
Step 2: Install Python Dependencies
bash
cd aarcs_voice_agent/emergency_voice_agent
pip install -r requirements.txt
pip install python-dotenv firebase-admin
Step 3: Get Your Firebase Service Account Key
Go to Firebase Console

Select the project aarcs-2f28b

Click on Project Settings (gear icon) → Service Accounts

Click "Generate New Private Key"

Save the downloaded JSON file - this is your secret key!

Step 4: Create a Secure Folder for the Key (Outside Git)
Create a folder outside your project directory to store the key:

Windows PowerShell:

powershell
# Create folder in your user directory
mkdir C:\Users\$env:USERNAME\aarcs_secrets
Mac/Linux:

bash
# Create folder in your home directory
mkdir ~/aarcs_secrets
Step 5: Move the Key to the Secure Folder
Move the downloaded serviceAccountKey.json to the folder you just created:

Windows PowerShell:

powershell
# Example (adjust source path to where you downloaded it)
move C:\Users\$env:USERNAME\Downloads\serviceAccountKey.json C:\Users\$env:USERNAME\aarcs_secrets\
Mac/Linux:

bash
mv ~/Downloads/serviceAccountKey.json ~/aarcs_secrets/
Step 6: Create Your Local .env File Using PowerShell
Important: Do this in PowerShell/Terminal, not a text editor!

powershell
# Navigate to the emergency_voice_agent folder
cd C:\IMPORTANT DOCUMENTS\STUDY\Flutter Projects\AARCS-AMBULANCE\aarcs_voice_agent\emergency_voice_agent

# Create the .env file with proper formatting
@"
GOOGLE_APPLICATION_CREDENTIALS=C:/Users/$env:USERNAME/aarcs_secrets/serviceAccountKey.json
FIREBASE_DATABASE_URL=https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app
"@ | Out-File -FilePath .env -Encoding utf8
For Mac/Linux:

bash
# Navigate to the emergency_voice_agent folder
cd ~/AARCS-AMBULANCE/aarcs_voice_agent/emergency_voice_agent

# Create the .env file
echo "GOOGLE_APPLICATION_CREDENTIALS=/Users/$USER/aarcs_secrets/serviceAccountKey.json" > .env
echo "FIREBASE_DATABASE_URL=https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app" >> .env
Step 7: Verify the .env File Was Created Correctly
powershell
# Check the content
Get-Content .env
You should see:

text
GOOGLE_APPLICATION_CREDENTIALS=C:/Users/YOUR_USERNAME/aarcs_secrets/serviceAccountKey.json
FIREBASE_DATABASE_URL=https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app
Note: The path uses forward slashes (/) not backslashes (\), and the folder name is aarcs_secrets with an underscore.

Step 8: Verify the Key File Exists
powershell
# Test if the path is correct
Test-Path "C:/Users/$env:USERNAME/aarcs_secrets/serviceAccountKey.json"
Should return True.

Step 9: Run the Connection Test
powershell
python test_firebase_connection.py
You should see a success message indicating Firebase is properly configured.

Step 10: Run the NLP Agent
powershell
python main_ai.py
✅ Verification Checklist
Firebase service account key is stored in C:\Users\YOUR_USERNAME\aarcs_secrets\ (outside project)

.env file exists in emergency_voice_agent folder with correct paths

Path in .env uses forward slashes (/) not backslashes

Folder name is aarcs_secrets (with underscore, not hyphen)

Test script runs without errors

NLP agent starts without Firebase errors

Dashboard shows real-time call logs when agent runs

🔒 Security Notes
NEVER commit your serviceAccountKey.json to Git

NEVER commit your .env file to Git (it's already in .gitignore)

The .env file only contains the path to your key, not the key itself

The actual key file is stored outside the project directory

Each developer must generate their own service account key

If a key is accidentally exposed, revoke it immediately in Firebase Console

🆘 Troubleshooting
"Key file not found" error
Run Get-Content .env to check the path

Verify the folder name is aarcs_secrets (underscore) not aarcs-secrets (hyphen)

Check that the key file actually exists at that location

Make sure you're using forward slashes (/) not backslashes (\)

Test-Path returns False even though file exists
Double-check the folder name spelling

Verify the username in the path is correct

Check if the file extension is .json (not hidden as .json.txt)

No logs appearing in dashboard
Run with debug mode: python main_ai.py

Check Firebase Console for live_calls node

Verify dashboard is on the Live Trip page

📁 File Structure After Setup
text
AARCS-AMBULANCE/
├── aarcs_voice_agent/
│   └── emergency_voice_agent/
│       ├── .env (your local config - NEVER COMMIT)
│       ├── main_ai.py
│       ├── firebase_client.py
│       └── test_firebase_connection.py
└── C:/Users/YOUR_USERNAME/aarcs_secrets/ (OUTSIDE project)
    └── serviceAccountKey.json (your secret key)
🎯 Quick Setup Commands (Windows PowerShell)
Copy and paste this entire block into PowerShell:

powershell
# Navigate to the right folder
cd C:\IMPORTANT DOCUMENTS\STUDY\Flutter Projects\AARCS-AMBULANCE\aarcs_voice_agent\emergency_voice_agent

# Create the .env file
@"
GOOGLE_APPLICATION_CREDENTIALS=C:/Users/$env:USERNAME/aarcs_secrets/serviceAccountKey.json
FIREBASE_DATABASE_URL=https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app
"@ | Out-File -FilePath .env -Encoding utf8

# Verify it worked
Get-Content .env

# Test the connection
python test_firebase_connection.py
🎯 Quick Setup Commands (Mac/Linux)
bash
# Navigate to the right folder
cd ~/AARCS-AMBULANCE/aarcs_voice_agent/emergency_voice_agent

# Create the .env file
echo "GOOGLE_APPLICATION_CREDENTIALS=/Users/$USER/aarcs_secrets/serviceAccountKey.json" > .env
echo "FIREBASE_DATABASE_URL=https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app" >> .env

# Verify it worked
cat .env

# Test the connection
python test_firebase_connection.py