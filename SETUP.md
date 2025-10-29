# AARCS System - Complete Setup Guide

## System Overview

AARCS (Advanced Ambulance Response & Control System) consists of:
- **Ambulance Mobile App** - For ambulance drivers
- **Traffic Police Mobile App** - For traffic police officers
- **Backend Authentication Server** - Node.js server with Firebase integration

## Prerequisites

- Flutter SDK (3.9.0 or higher)
- Node.js (v18 or higher)
- Android Studio / VS Code
- Firebase Account Access
- Ngrok Account (for internet-wide access)

---

## Part 1: Backend Server Setup

### Step 1: Install Dependencies

cd aarcs_backend
npm install


### Step 2: Get Firebase Service Account Key

**Required File:** `aarcs_backend/config/firebase-service-account.json`

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select the **AARCS** project (aarcs-2f28b)
3. Navigate to **Project Settings** (gear icon) → **Service Accounts**
4. Click **"Generate new private key"**
5. Download the JSON file
6. **Important:** Rename it to `firebase-service-account.json`
7. Place it in `aarcs_backend/config/` folder

**File Structure:**
aarcs_backend/
├── config/
│ └── firebase-service-account.json ← Place here (NOT in Git)
├── server.js
└── package.json


### Step 3: Start Backend Server Locally

cd aarcs_backend
node server.js

You should see:
🚀 AARCS Authentication Server Started
📡 Server running on: http://localhost:3000
🚑 Ambulances: AMB001, AMB002, AMB003
🚔 Police: POL001, POL002, POL003

**Keep this terminal running.**

---

## Part 2: Expose Backend with Ngrok (Internet Access)

### Step 1: Install and Setup Ngrok

1. Download from: https://ngrok.com/download
2. Install using the Windows installer
3. Sign up for free account at: https://dashboard.ngrok.com
4. Get your authtoken from: https://dashboard.ngrok.com/get-started/your-authtoken

### Step 2: Authenticate Ngrok

ngrok config add-authtoken YOUR_AUTHTOKEN_HERE


### Step 3: Start Ngrok Tunnel

**Open a NEW terminal** and run:

ngrok http 3000

You'll see output like:
Forwarding https://abcd-1234-5678-efgh.ngrok-free.app -> http://localhost:3000


**Copy the Forwarding URL** (the `https://...ngrok-free.app` part)

**⚠️ IMPORTANT:** Keep this terminal running. Your public URL will change if you restart ngrok.

---

## Part 3: Ambulance App Setup

### Step 1: Navigate to App Directory

cd aarcs_ambulance

### Step 2: Install Dependencies

flutter pub get

### Step 3: Create `.env` File

**Required File:** `aarcs_ambulance/.env`

Create a file named `.env` in the `aarcs_ambulance` folder:

notepad .env

**Content (use YOUR ngrok URL):**
BACKEND_URL=https://abcd-1234-5678-efgh.ngrok-free.app

Replace `abcd-1234-5678-efgh.ngrok-free.app` with your actual ngrok URL from Part 2, Step 3.

### Step 4: Run the App

flutter run

### Step 5: Test Login

| Ambulance ID | Password |
|--------------|----------|
| AMB001 | emergency123 |
| AMB002 | emergency234 |
| AMB003 | emergency456 |

---

## Part 4: Traffic Police App Setup

### Step 1: Navigate to App Directory

cd aarcs_traffic-police

### Step 2: Install Dependencies

flutter pub get

### Step 3: Create `.env` File

**Required File:** `aarcs_traffic-police/.env`

Create a file named `.env` in the `aarcs_traffic-police` folder:

notepad .env

**Content (use YOUR ngrok URL):**
BACKEND_URL=https://abcd-1234-5678-efgh.ngrok-free.app

Use the **same ngrok URL** from Part 2, Step 3.

### Step 4: Run the App

flutter run

### Step 5: Test Login

| Police ID | Password |
|-----------|----------|
| POL001 | traffic123 |
| POL002 | traffic234 |
| POL003 | traffic345 |

---

## Project Structure

AARCS-AMBULANCE/
├── aarcs_ambulance/ # Ambulance mobile app
│ ├── lib/
│ │ ├── main.dart # App entry with Firebase auth
│ │ └── screens/
│ └── .env # Backend URL (NOT in repo)
│
├── aarcs_backend/ # Authentication server
│ ├── config/
│ │ └── firebase-service-account.json # Firebase key (NOT in repo)
│ ├── server.js # Backend server
│ └── package.json
│
└── aarcs_traffic-police/ # Traffic police mobile app
├── lib/
│ ├── main.dart # App entry with Firebase auth
│ └── screens/
└── .env # Backend URL (NOT in repo)

---

## Running Everything (Quick Start)

You'll need **4 terminals**:

### Terminal 1 - Backend Server
cd D:\AARCS-AMBULANCE\aarcs_backend
node server.js

### Terminal 2 - Ngrok Tunnel
ngrok http 3000
Copy the ngrok URL and update .env files if changed

### Terminal 3 - Ambulance App
cd D:\AARCS-AMBULANCE\aarcs_ambulance
flutter run

### Terminal 4 - Traffic Police App
cd D:\AARCS-AMBULANCE\aarcs_traffic-police
flutter run

---

## Important Security Notes

### ⚠️ Never Commit These Files to Git:

- `firebase-service-account.json` - Firebase admin credentials
- `.env` files - Backend URLs
- Any file containing passwords or API keys

These files are protected by `.gitignore` and should remain local only.

---

## Network Requirements

### Both Apps Work From:
- ✅ Any Wi-Fi network
- ✅ Mobile data (4G/5G)
- ✅ Different networks (apps don't need to be on same Wi-Fi)
- ✅ Anywhere with internet connection

### Requirements:
- Backend server must be running
- Ngrok tunnel must be active
- Internet connection on mobile devices

---

## Ngrok Notes

### Free Tier Features:
- ✅ Works from anywhere with internet
- ✅ HTTPS enabled automatically
- ⚠️ URL changes every time you restart ngrok
- ⚠️ Session expires after 8 hours
- ⚠️ Shows ngrok banner page on first visit

### When Ngrok URL Changes:

If you stop and restart ngrok, you'll get a new URL. You must:

1. Copy the new ngrok URL from terminal
2. Update **both** `.env` files:
    - `aarcs_ambulance/.env`
    - `aarcs_traffic-police/.env`
3. Hot restart both apps:
    - Press `r` in Flutter terminal
    - Or stop and `flutter run` again

## Troubleshooting

### Backend won't start
- ✅ Verify `firebase-service-account.json` is in correct location
- ✅ Check Firebase project ID matches (aarcs-2f28b)
- ✅ Run `npm install` to ensure dependencies are installed

### App shows connection error
- ✅ Ensure backend server is running
- ✅ Verify ngrok tunnel is active
- ✅ Check `.env` file has correct ngrok URL
- ✅ Restart app after updating `.env`
- ✅ Check mobile device has internet connection

### Firebase Authentication Error
- ✅ Verify Firebase Authentication is enabled in Console
- ✅ Ensure Email/Password provider is enabled
- ✅ Check Firebase service account has correct permissions

### Ngrok session expired
- ✅ Restart ngrok: `ngrok http 3000`
- ✅ Copy new URL and update `.env` files
- ✅ Hot restart both apps

### Wrong credentials accepted
- ✅ Verify you're using correct app for credentials
- ✅ Ambulance credentials (AMB*) only work in ambulance app
- ✅ Police credentials (POL*) only work in traffic police app

---

## Role-Based Access Control

### Security Features:
- ✅ Separate authentication endpoints for each app type
- ✅ Role-specific Firebase custom tokens
- ✅ Ambulance credentials cannot access police app
- ✅ Police credentials cannot access ambulance app
- ✅ Token validation on every request

### Endpoints:
- Ambulance: `POST /authenticate` or `/authenticate/ambulance`
- Police: `POST /authenticate/police`

---

## Team Collaboration

### To Share Firebase Access:

1. Go to Firebase Console → Project Settings → Users and Permissions
2. Add team member emails with appropriate roles
3. They can generate their own service account keys

### To Share Ngrok URL:

Simply share the ngrok URL from Terminal 2 with your team. They can use it in their `.env` files.

**⚠️ Security Note:** The ngrok URL is publicly accessible. Only use test credentials in development.

---

## Support

For issues or questions:
- Check troubleshooting section above
- Review Firebase Console for authentication logs
- Check ngrok dashboard for traffic logs
- Create an issue on GitHub repository

---

## License

This project is for educational/internal use. Ensure compliance with all applicable regulations for emergency services systems.