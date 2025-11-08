# AARCS System - Complete Setup Guide

## System Overview

AARCS (Automated Ambulance Route Clearance System) consists of:
- **Ambulance Mobile App** - For ambulance drivers
- **Traffic Police Mobile App** - For traffic police officers
- **Backend Authentication Server** - Cloud-hosted Node.js server with Firebase integration

## Prerequisites

- Flutter SDK (3.9.0 or higher)
- Android Studio / VS Code
- Internet connection on mobile devices
- Firebase Account Access (for developers only)

***

## Part 1: Backend Server (Already Deployed)

### ✅ Server Status

The AARCS authentication server is **already deployed and running 24/7** on Render cloud platform.

**Server URL:** `https://aarcs-auth-server.onrender.com`

### Features:
- ✅ Always accessible from anywhere with internet
- ✅ No local server setup required
- ✅ Automatic SSL/HTTPS security
- ✅ Free cloud hosting
- ⚠️ First request after inactivity may take 30-60 seconds (server waking up)

### Health Check

To verify server is running, visit:
https://aarcs-auth-server.onrender.com/health

Expected response:json
{"status":"Server running","timestamp":"..."}

***

## Part 2: Ambulance App Setup

### Step 1: Navigate to App Directory

cd aarcs_ambulance

### Step 2: Install Dependencies

flutter pub get

### Step 3: Verify Backend URL Configuration

The app is already configured to use the cloud server. No `.env` file needed.

**Backend URL is hardcoded in code:** `https://aarcs-auth-server.onrender.com`

### Step 4: Run the App

flutter run

**Note:** First login may take 30-60 seconds if server was sleeping. Subsequent logins will be instant.

### Step 5: Test Login

| Ambulance ID | Password |
|--------------|----------|
| AMB001 | emergency123 |
| AMB002 | emergency234 |
| AMB003 | emergency456 |

***

## Part 3: Traffic Police App Setup

### Step 1: Navigate to App Directory

cd aarcs_traffic_police_app

### Step 2: Install Dependencies

flutter pub get

### Step 3: Verify Backend URL Configuration

The app is already configured to use the cloud server at `https://aarcs-auth-server.onrender.com`

### Step 4: Run the App

flutter run

**Note:** First login may take 30-60 seconds if server was sleeping. Subsequent logins will be instant.

### Step 5: Test Login

| Police ID | Password |
|-----------|----------|
| POL001 | traffic123 |
| POL002 | traffic234 |
| POL003 | traffic345 |

***

## Project Structure

AARCS-AMBULANCE/
├── aarcs_ambulance/              # Ambulance mobile app
│   ├── lib/
│   │   ├── main.dart             # App entry with Firebase auth
│   │   └── screens/
│   │       ├── dashboard.dart
│   │       └── route_navigation.dart
│   └── pubspec.yaml
│
├── aarcs_backend/                # Backend server (deployed to Render)
│   ├── server.js                 # Authentication server
│   ├── package.json
│   └── config/
│       └── firebase-service-account.json  # (Deployed securely)
│
└── aarcs_traffic_police_app/     # Traffic police mobile app
    ├── lib/
    │   ├── main.dart             # App entry with Firebase auth
    │   └── screens/
    └── pubspec.yaml

***

## Running Everything (Quick Start)

You only need **2 terminals** (no backend setup needed):

### Terminal 1 - Ambulance App
cd aarcs_ambulance
flutter run

### Terminal 2 - Traffic Police App
cd aarcs_traffic_police_app
flutter run

That's it! The backend server runs automatically in the cloud.

***

## Network Requirements

### Both Apps Work From:
- ✅ Any Wi-Fi network
- ✅ Mobile data (4G/5G)
- ✅ Different networks (apps don't need to be on same network)
- ✅ Anywhere in the world with internet connection
- ✅ No VPN or special network configuration required

### Requirements:
- Internet connection on mobile devices
- Backend server is automatically available 24/7

***

## Cloud Hosting Details

### Render Free Tier Features:
- ✅ 24/7 server availability
- ✅ Automatic HTTPS/SSL
- ✅ Fixed URL (never changes)
- ✅ Accessible from anywhere
- ⚠️ Server sleeps after 15 minutes of inactivity
- ⚠️ Cold start takes 30-60 seconds (first login after sleep)
- ✅ 750 hours/month runtime (enough for continuous operation)

### Server Wake-Up Behavior:

**First login after inactivity:**
- Takes 30-60 seconds
- Shows "Connecting to server..." message
- This is normal and expected

**Subsequent logins:**
- Instant response (< 1 second)
- Server stays active for 15 minutes after last request

***

## Troubleshooting

### "TimeoutException" or "Connection Error"
**Cause:** Server is waking up from sleep (first request after inactivity)

**Solution:**
- ✅ Wait 30-60 seconds and try again
- ✅ App has 90-second timeout to handle this
- ✅ Check your internet connection
- ✅ Verify server health at: `https://aarcs-auth-server.onrender.com/health`

### "Invalid credentials" error
- ✅ Verify you're using correct app for credentials
- ✅ Ambulance credentials (AMB*) only work in ambulance app
- ✅ Police credentials (POL*) only work in traffic police app
- ✅ Check for typos in ID or password

### Firebase Authentication Error
- ✅ Ensure device has internet connection
- ✅ Check Firebase service is operational
- ✅ Try restarting the app

### App won't compile
- ✅ Run `flutter pub get` to install dependencies
- ✅ Run `flutter clean` then `flutter pub get`
- ✅ Ensure Flutter SDK is up to date: `flutter upgrade`

### "Server not responding"
- ✅ Check server status at health endpoint
- ✅ Verify internet connection on device
- ✅ Wait 60 seconds for server wake-up
- ✅ Check Render dashboard for server status

---

## Role-Based Access Control

### Security Features:
- ✅ Separate authentication endpoints for each app type
- ✅ Role-specific Firebase custom tokens
- ✅ Ambulance credentials cannot access police app
- ✅ Police credentials cannot access ambulance app
- ✅ Token validation on every request
- ✅ Hardcoded credentials validated server-side

### Endpoints:
- **Ambulance:** `POST https://aarcs-auth-server.onrender.com/authenticate/ambulance`
- **Police:** `POST https://aarcs-auth-server.onrender.com/authenticate/police`
- **Health:** `GET https://aarcs-auth-server.onrender.com/health`

***

## For Developers: Backend Deployment

### Server is Deployed on Render

**Dashboard:** https://dashboard.render.com

**Deployment Details:**
- **Platform:** Render Free Tier
- **Repository:** https://github.com/11prem/AARCS-AMBULANCE
- **Root Directory:** `aarcs_backend`
- **Build Command:** `npm install`
- **Start Command:** `node server.js`
- **Port:** Auto-assigned by Render

### To Update Backend Server:

1. Make changes to `aarcs_backend/server.js`
2. Commit and push to GitHub:

   git add .
   git commit -m "Update backend server"
   git push origin main

3. Render automatically deploys the changes
4. Check deployment status at Render dashboard

### Environment Configuration:

Firebase service account is configured in Render as a Secret File:
- **Path:** `/etc/secrets/firebase-service-account.json`
- **Configured in:** Render Dashboard → Settings → Advanced → Secret Files

***

## Security Notes

### ⚠️ Never Commit These Files to Git:

- `firebase-service-account.json` - Firebase admin credentials
- Any file containing passwords or API keys
- `.env` files (if used in future)

These files are protected by `.gitignore` and should remain secure.

### Production Credentials:

The hardcoded credentials (AMB001-003, POL001-003) are for development/demo purposes only. In production:
- Replace with secure database-backed authentication
- Implement proper user management
- Use environment variables for sensitive data

***

## Team Collaboration

### For App Developers:

No backend setup required. Simply:
1. Clone the repository
2. Run `flutter pub get`
3. Run `flutter run`

### For Backend Developers:

To modify the backend:
1. Request access to Firebase Console
2. Request access to Render Dashboard
3. Clone repository and work in `aarcs_backend/` folder
4. Test locally with `node server.js` (requires Firebase service account)
5. Push changes to GitHub for automatic deployment

---

## Performance Optimization

### To Avoid Cold Starts:

**Option 1: Use UptimeRobot (Recommended)**
1. Sign up at [uptimerobot.com](https://uptimerobot.com) (free)
2. Add monitor:
   - **URL:** `https://aarcs-auth-server.onrender.com/health`
   - **Interval:** Every 5 minutes
3. Server stays warm 24/7

**Option 2: Upgrade Render Plan**
- Upgrade to paid plan ($7/month) for always-on service
- No cold starts, instant response

***

## System Architecture

┌─────────────────────┐
│  Ambulance App      │
│  (Flutter)          │
└──────────┬──────────┘
           │
           │ HTTPS
           ▼
┌──────────────────────────────────────────────┐
│  AARCS Auth Server                           │
│  (Render Cloud)                              │
│  https://aarcs-auth-server.onrender.com      │
└──────────┬───────────────────────────────────┘
           │
           │ Firebase Admin SDK
           ▼
┌─────────────────────────────────┐
│  Firebase Services              │
│  - Authentication               │
│  - Firestore Database           │
│  - Cloud Storage                │
└─────────────────────────────────┘
           ▲
           │ HTTPS
           │
┌──────────┴──────────┐
│  Traffic Police App │
│  (Flutter)          │
└─────────────────────┘

***

## Support & Resources

### Documentation:
- **Firebase:** https://firebase.google.com/docs
- **Flutter:** https://flutter.dev/docs
- **Render:** https://render.com/docs

### Monitoring:
- **Server Health:** https://aarcs-auth-server.onrender.com/health
- **Render Dashboard:** https://dashboard.render.com
- **Firebase Console:** https://console.firebase.google.com

### For Issues:
1. Check troubleshooting section above
2. Review server logs in Render dashboard
3. Check Firebase Console for authentication logs
4. Create an issue on GitHub repository

***

## Quick Reference

### Ambulance Credentials
AMB001 / emergency123
AMB002 / emergency234
AMB003 / emergency456

### Police Credentials
POL001 / traffic123
POL002 / traffic234
POL003 / traffic345

### Server URL
https://aarcs-auth-server.onrender.com

### Commands
# Install dependencies
flutter pub get

# Run ambulance app
cd aarcs_ambulance && flutter run

# Run police app
cd aarcs_traffic_police_app && flutter run

# Build APK
flutter build apk --release

***

**Last Updated:** November 2025  
**Backend Version:** 1.0.0  
**Deployment Platform:** Render Cloud Platform