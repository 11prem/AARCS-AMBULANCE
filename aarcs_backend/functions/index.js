const functions = require("firebase-functions");
const express = require("express");
const admin = require("firebase-admin");
const bodyParser = require("body-parser");
const cors = require("cors");

// Initialize Firebase Admin SDK
const serviceAccount = require("./config/firebase-service-account.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const app = express();
app.use(cors({origin: true})); // Allow all origins for mobile apps
app.use(bodyParser.json());

// Ambulance credentials (same as your server.js)
const ambulanceCredentials = {
  "AMB001": "emergency123",
  "AMB002": "emergency234",
  "AMB003": "emergency456",
};

// Traffic Police credentials (same as your server.js)
const trafficPoliceCredentials = {
  "POL001": "traffic123",
  "POL002": "traffic234",
  "POL003": "traffic345",
};

// Helper function to get current timestamp
function getTimestamp() {
  const now = new Date();
  return now.toLocaleString("en-IN", {timeZone: "Asia/Kolkata"});
}

// Shared ambulance authentication logic
async function authenticateAmbulance(req, res) {
  const {ambulanceId, password} = req.body;
  const timestamp = getTimestamp();

  console.log(`🚑 [${timestamp}] Ambulance Login Attempt: ${ambulanceId}`);

  if (ambulanceCredentials[ambulanceId] && ambulanceCredentials[ambulanceId] === password) {
    try {
      const customToken = await admin.auth().createCustomToken(ambulanceId, {
        userId: ambulanceId,
        role: "ambulance_driver",
        type: "ambulance",
      });

      console.log(`✅ [${timestamp}] ${ambulanceId} logged in successfully!`);

      res.json({
        success: true,
        token: customToken,
        userId: ambulanceId,
        ambulanceId: ambulanceId,
        role: "ambulance_driver",
      });
    } catch (error) {
      console.error(`❌ [${timestamp}] Token generation failed for ${ambulanceId}: ${error.message}`);
      res.status(500).json({
        success: false,
        message: "Server error",
      });
    }
  } else {
    console.log(`❌ [${timestamp}] Login failed for ${ambulanceId}`);
    res.status(401).json({
      success: false,
      message: "Invalid Ambulance ID or Password",
    });
  }
}

// Legacy ambulance endpoint
app.post("/authenticate", authenticateAmbulance);

// New ambulance endpoint
app.post("/authenticate/ambulance", authenticateAmbulance);

// Traffic Police authentication endpoint
app.post("/authenticate/police", async (req, res) => {
  const {policeId, password} = req.body;
  const timestamp = getTimestamp();

  console.log(`🚔 [${timestamp}] Traffic Police Login Attempt: ${policeId}`);

  if (trafficPoliceCredentials[policeId] && trafficPoliceCredentials[policeId] === password) {
    try {
      const customToken = await admin.auth().createCustomToken(policeId, {
        userId: policeId,
        role: "traffic_police",
        type: "police",
      });

      console.log(`✅ [${timestamp}] ${policeId} logged in successfully!`);

      res.json({
        success: true,
        token: customToken,
        userId: policeId,
        role: "traffic_police",
      });
    } catch (error) {
      console.error(`❌ [${timestamp}] Token generation failed for ${policeId}: ${error.message}`);
      res.status(500).json({
        success: false,
        message: "Server error",
      });
    }
  } else {
    console.log(`❌ [${timestamp}] Login failed for ${policeId}`);
    res.status(401).json({
      success: false,
      message: "Invalid Police ID or Password",
    });
  }
});

// Health check endpoint
app.get("/health", (req, res) => {
  const timestamp = getTimestamp();
  console.log(`💚 [${timestamp}] Health check requested`);
  res.json({status: "Server running", timestamp: timestamp});
});

// Export the Express app as a Cloud Function
exports.api = functions.https.onRequest(app);
