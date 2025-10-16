const express = require('express');
const admin = require('firebase-admin');
const bodyParser = require('body-parser');
const cors = require('cors');

// Initialize Firebase Admin SDK
const serviceAccount = require('./config/firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Your ambulance credentials
const validCredentials = {
  'AMB001': 'emergency123',
  'AMB002': 'emergency234',
  'AMB003': 'emergency456'
};

// Helper function to get current timestamp
function getTimestamp() {
  const now = new Date();
  return now.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
}

// Login endpoint with enhanced logging
app.post('/authenticate', async (req, res) => {
  const { ambulanceId, password } = req.body;
  const timestamp = getTimestamp();

  console.log('\n' + '='.repeat(60));
  console.log(`🚑 [${timestamp}] Login Attempt`);
  console.log(`   Ambulance ID: ${ambulanceId}`);
  console.log('='.repeat(60));

  if (validCredentials[ambulanceId] && validCredentials[ambulanceId] === password) {
    try {
      // Create custom token with ambulance ID as uid
      const customToken = await admin.auth().createCustomToken(ambulanceId, {
        ambulanceId: ambulanceId,
        role: 'ambulance_driver'
      });

      console.log(`✅ [${timestamp}] ${ambulanceId} logged in successfully!`);
      console.log(`   Token generated for: ${ambulanceId}`);
      console.log(`   Role: ambulance_driver`);
      console.log('='.repeat(60) + '\n');

      res.json({
        success: true,
        token: customToken,
        ambulanceId: ambulanceId
      });
    } catch (error) {
      console.error(`❌ [${timestamp}] Token generation failed for ${ambulanceId}`);
      console.error(`   Error: ${error.message}`);
      console.log('='.repeat(60) + '\n');

      res.status(500).json({
        success: false,
        message: 'Server error'
      });
    }
  } else {
    console.log(`❌ [${timestamp}] Login failed for ${ambulanceId}`);
    console.log(`   Reason: Invalid credentials`);
    console.log('='.repeat(60) + '\n');

    res.status(401).json({
      success: false,
      message: 'Invalid Ambulance ID or Password'
    });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  const timestamp = getTimestamp();
  console.log(`💚 [${timestamp}] Health check requested`);
  res.json({ status: 'Server running', timestamp: timestamp });
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log('\n' + '█'.repeat(60));
  console.log('🚀 AARCS Authentication Server Started');
  console.log('█'.repeat(60));
  console.log(`📡 Server running on: http://localhost:${PORT}`);
  console.log(`📁 Firebase config loaded successfully`);
  console.log(`⏰ Server started at: ${getTimestamp()}`);
  console.log(`🔐 Authentication ready for ambulances: ${Object.keys(validCredentials).join(', ')}`);
  console.log('█'.repeat(60) + '\n');
  console.log('Waiting for login requests...\n');
});
