const express = require('express');
const admin = require('firebase-admin');
const bodyParser = require('body-parser');
const cors = require('cors');

// Initialize Firebase Admin SDK
const serviceAccount = require('/etc/secrets/firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Ambulance credentials
const ambulanceCredentials = {
  'AMB001': 'emergency123',
  'AMB002': 'emergency234',
  'AMB003': 'emergency456'
};

// Traffic Police credentials
const trafficPoliceCredentials = {
  'POL001': 'traffic123',
  'POL002': 'traffic234',
  'POL003': 'traffic345'
};

// Helper function to get current timestamp
function getTimestamp() {
  const now = new Date();
  return now.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
}

// Shared ambulance authentication logic
async function authenticateAmbulance(req, res) {
  const { ambulanceId, password } = req.body;
  const timestamp = getTimestamp();

  console.log('\n' + '='.repeat(60));
  console.log(`🚑 [${timestamp}] Ambulance Login Attempt`);
  console.log(`   Ambulance ID: ${ambulanceId}`);
  console.log('='.repeat(60));

  if (ambulanceCredentials[ambulanceId] && ambulanceCredentials[ambulanceId] === password) {
    try {
      const customToken = await admin.auth().createCustomToken(ambulanceId, {
        userId: ambulanceId,
        role: 'ambulance_driver',
        type: 'ambulance'
      });

      console.log(`✅ [${timestamp}] ${ambulanceId} logged in successfully!`);
      console.log(`   Role: ambulance_driver`);
      console.log('='.repeat(60) + '\n');

      res.json({
        success: true,
        token: customToken,
        userId: ambulanceId,
        ambulanceId: ambulanceId,  // For backward compatibility
        role: 'ambulance_driver'
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
}

// Legacy ambulance endpoint (for backward compatibility)
app.post('/authenticate', authenticateAmbulance);

// New ambulance endpoint
app.post('/authenticate/ambulance', authenticateAmbulance);

// Traffic Police authentication endpoint
app.post('/authenticate/police', async (req, res) => {
  const { policeId, password } = req.body;
  const timestamp = getTimestamp();

  console.log('\n' + '='.repeat(60));
  console.log(`🚔 [${timestamp}] Traffic Police Login Attempt`);
  console.log(`   Police ID: ${policeId}`);
  console.log('='.repeat(60));

  if (trafficPoliceCredentials[policeId] && trafficPoliceCredentials[policeId] === password) {
    try {
      const customToken = await admin.auth().createCustomToken(policeId, {
        userId: policeId,
        role: 'traffic_police',
        type: 'police'
      });

      console.log(`✅ [${timestamp}] ${policeId} logged in successfully!`);
      console.log(`   Role: traffic_police`);
      console.log('='.repeat(60) + '\n');

      res.json({
        success: true,
        token: customToken,
        userId: policeId,
        role: 'traffic_police'
      });
    } catch (error) {
      console.error(`❌ [${timestamp}] Token generation failed for ${policeId}`);
      console.error(`   Error: ${error.message}`);
      console.log('='.repeat(60) + '\n');

      res.status(500).json({
        success: false,
        message: 'Server error'
      });
    }
  } else {
    console.log(`❌ [${timestamp}] Login failed for ${policeId}`);
    console.log(`   Reason: Invalid credentials`);
    console.log('='.repeat(60) + '\n');

    res.status(401).json({
      success: false,
      message: 'Invalid Police ID or Password'
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
  console.log(`\n🚑 Ambulances: ${Object.keys(ambulanceCredentials).join(', ')}`);
  console.log(`🚔 Police: ${Object.keys(trafficPoliceCredentials).join(', ')}`);
  console.log('█'.repeat(60) + '\n');
  console.log('Waiting for login requests...\n');
});
