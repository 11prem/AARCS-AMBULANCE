# AARCS Ambulance System - Setup Guide

## Prerequisites

- Flutter SDK (3.9.0 or higher)
- Node.js (v18 or higher)
- Android Studio / VS Code
- Firebase Account Access

## Setup Instructions

### 1. Clone the Repository

git clone https://github.com/11prem/AARCS-AMBULANCE.git
cd AARCS-AMBULANCE


### 2. Backend Setup

#### Step 2.1: Install Dependencies

cd aarcs_backend
npm install


#### Step 2.2: Get Firebase Service Account Key

**Required File:** `aarcs_backend/config/firebase-service-account.json`

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select the **AARCS** project
3. Navigate to **Project Settings** (gear icon) → **Service Accounts**
4. Click **"Generate new private key"**
5. Download the JSON file
6. **Important:** Rename it to `firebase-service-account.json`
7. Place it in `aarcs_backend/config/` folder

**File Structure:**
aarcs_backend/
├── config/
│ └── firebase-service-account.json ← Place here
├── server.js
└── package.json


#### Step 2.3: Start Backend Server

node server.js


You should see:
🚀 AARCS Authentication Server Started
📡 Server running on: http://localhost:3000


### 3. Flutter App Setup

#### Step 3.1: Install Dependencies

cd ../aarcs_ambulance
flutter pub get


#### Step 3.2: Create .env File

**Required File:** `aarcs_ambulance/.env`

Create a file named `.env` in the `aarcs_ambulance` folder with this content:

**For Android Emulator:**
BACKEND_URL=http://10.0.2.2:3000


**For Physical Device:**
BACKEND_URL=http://YOUR_COMPUTER_IP:3000


Replace `YOUR_COMPUTER_IP` with your actual IP address (find using `ipconfig` on Windows).

#### Step 3.3: Run the App

flutter run


### 4. Test Login

Use these credentials to test:

| Ambulance ID | Password |
|--------------|----------|
| AMB001 | emergency123 |
| AMB002 | emergency234 |
| AMB003 | emergency456 |

## Project Structure

AARCS-AMBULANCE/
├── aarcs_ambulance/ # Flutter mobile app
│ ├── lib/
│ │ ├── main.dart # App entry point with authentication
│ │ └── screens/ # App screens
│ └── .env # Backend URL (NOT in repo - create manually)
│
├── aarcs_backend/ # Node.js authentication server
│ ├── config/
│ │ └── firebase-service-account.json # Firebase key (NOT in repo)
│ ├── server.js # Backend server
│ └── package.json # Node dependencies
│
└── aarcs_traffic-police/ # Traffic police app


## Important Security Notes

⚠️ **Never commit these files to Git:**
- `firebase-service-account.json`
- `.env` files
- Any file containing credentials or API keys

These files are protected by `.gitignore` and should remain local only.

## Troubleshooting

### Backend won't start
- Verify `firebase-service-account.json` is in the correct location
- Check Firebase project ID matches in the JSON file

### App shows "TimeoutException"
- Ensure backend server is running
- For physical devices, use correct computer IP in `.env`
- Ensure phone and computer are on the same Wi-Fi network

### Firebase Authentication Error
- Check Firebase Authentication is enabled in Firebase Console
- Verify Email/Password provider is enabled

Then run:

cd D:\AARCS-AMBULANCE
git add SETUP.md
git commit -m "docs: Add comprehensive setup guide for team members"
git push origin main