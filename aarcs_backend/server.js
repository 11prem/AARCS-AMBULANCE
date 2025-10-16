const express = require('express');
const admin = require('firebase-admin');
const bodyParser = require('body-parser');
const cors = require('cors');

// Initialize Firebase Admin SDK - CORRECTED PATH
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

// Login endpoint
app.post('/authenticate', async (req, res) => {
  const { ambulanceId, password } = req.body;

  console.log(`🚑 Login attempt: ${ambulanceId}`);

  if (validCredentials[ambulanceId] && validCredentials[ambulanceId] === password) {
    try {
      const customToken = await admin.auth().createCustomToken(ambulanceId, {
        ambulanceId: ambulanceId,
        role: 'ambulance_driver'
      });

      console.log(`✓ Login successful: ${ambulanceId}`);

      res.json({
        success: true,
        token: customToken,
        ambulanceId: ambulanceId
      });
    } catch (error) {
      console.error('❌ Token generation error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  } else {
    console.log(`✗ Invalid credentials for: ${ambulanceId}`);
    res.status(401).json({ success: false, message: 'Invalid Ambulance ID or Password' });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'Server running' });
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 AARCS Backend Server running on http://localhost:${PORT}`);
  console.log(`📁 Config loaded from: ./config/firebase-service-account.json`);
});
