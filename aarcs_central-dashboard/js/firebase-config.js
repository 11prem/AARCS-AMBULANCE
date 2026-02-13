// Firebase Configuration
const firebaseConfig = {
    apiKey: "AIzaSyBxJ6ZNgqW4NGRjsf_XmNZHjO70bZ3n-Xw",
    authDomain: "aarcs-2f28b.firebaseapp.com",
    databaseURL: "https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app",
    projectId: "aarcs-2f28b",
    storageBucket: "aarcs-2f28b.appspot.com",
    messagingSenderId: "1068070572886",
    appId: "1:1068070572886:web:5a5987e0117e5c347ad0db"
};

// Initialize Firebase
try {
    firebase.initializeApp(firebaseConfig);
    console.log('✅ Firebase initialized successfully');
} catch (error) {
    console.error('❌ Firebase initialization error:', error);
}

// Create database reference
const database = firebase.database();