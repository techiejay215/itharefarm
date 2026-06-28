const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');

// Modular imports for firebase-admin v12+
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

let serviceAccount;
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else {
  // Fallback for local development
  serviceAccount = require('./serviceAccountKey.json');
}

// Initialize the app using the modular syntax
initializeApp({
  credential: cert(serviceAccount)
});

// Get instances of Firestore and Messaging
const db = getFirestore();
const messaging = getMessaging();

const app = express();
app.use(cors());
app.use(bodyParser.json());

// ---------------------------------------------------------
// Health check
// ---------------------------------------------------------
app.get('/', (req, res) => {
  res.send('Ithare Farm Notification Server is running 🚀');
});

// ---------------------------------------------------------
// Endpoint: Send a test notification (with debug logs)
// ---------------------------------------------------------
app.get('/send-test-notification', async (req, res) => {
  try {
    console.log('📤 Fetching all users and tokens...');
    const usersSnapshot = await db.collection('users').get();
    console.log(`📊 Found ${usersSnapshot.size} users`); // <-- NEW

    let totalTokens = [];
    
    for (const userDoc of usersSnapshot.docs) {
      console.log(`👤 User: ${userDoc.id}`); // <-- NEW

      const tokensSnapshot = await db
        .collection('users')
        .doc(userDoc.id)
        .collection('tokens')
        .get();
      
      const tokens = tokensSnapshot.docs
        .map(doc => doc.data().token)
        .filter(token => token && token.length > 0);
      
      console.log(`🔑 Found ${tokens.length} tokens for user ${userDoc.id}`); // <-- NEW
      
      totalTokens = totalTokens.concat(tokens);
    }

    if (totalTokens.length === 0) {
      console.log('❌ No tokens found.');
      return res.status(404).json({ error: 'No tokens found' });
    }

    console.log(`✅ Found ${totalTokens.length} token(s). Sending notification...`);

    const message = {
      notification: {
        title: '🐄 Ithare Farm Test',
        body: 'This is a test notification from your Node server!',
      },
      data: {
        type: 'test_notification',
        payload: 'Server test payload',
      },
      tokens: totalTokens,
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
          },
        },
      },
    };

    const response = await messaging.sendEachForMulticast(message);
    console.log('📨 FCM Response:', {
      successCount: response.successCount,
      failureCount: response.failureCount,
    });

    res.json({
      success: true,
      message: 'Test notification sent successfully',
      successCount: response.successCount,
      failureCount: response.failureCount,
    });

  } catch (error) {
    console.error('❌ Error sending test notification:', error);
    res.status(500).json({ error: error.message });
  }
});

// ---------------------------------------------------------
// Daily Motivation Endpoint (Runs at 6:00 AM EAT)
// ---------------------------------------------------------
const quotes = [
  "It's gonna be a great day – make it count!",
  "Have a wonderful day, farmer!",
  "Rise and shine! Every sunrise brings new opportunities.",
  "Success is the sum of small efforts repeated day in and day out.",
  "A farmer's work is never done, but the harvest is always worth it.",
  "Believe you can, and you're halfway there. Have a productive day!",
  "The sun is up, and so are we! Let's make today amazing.",
  "Great things never came from comfort zones. Get out there!"
];

app.get('/daily-motivation', async (req, res) => {
  try {
    console.log('☀️ Sending daily motivational messages...');
    const usersSnapshot = await db.collection('users').get();
    
    let successCount = 0;
    let failureCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const name = userData.name || 'Farmer';

      const tokensSnapshot = await db
        .collection('users')
        .doc(userDoc.id)
        .collection('tokens')
        .get();
      
      const tokens = tokensSnapshot.docs
        .map(doc => doc.data().token)
        .filter(token => token && token.length > 0);

      if (tokens.length === 0) continue;

      const randomQuote = quotes[Math.floor(Math.random() * quotes.length)];

      const message = {
        notification: {
          title: `☀️ Good morning, ${name}!`,
          body: randomQuote,
        },
        data: {
          type: 'daily_motivation',
        },
        tokens: tokens,
        apns: {
          payload: {
            aps: {
              contentAvailable: true,
            },
          },
        },
      };

      const response = await messaging.sendEachForMulticast(message);
      successCount += response.successCount;
      failureCount += response.failureCount;
    }

    console.log(`✅ Daily motivation sent. Success: ${successCount}, Failures: ${failureCount}`);
    res.json({
      success: true,
      message: 'Daily motivation broadcast sent',
      totalSuccess: successCount,
      totalFailures: failureCount,
    });

  } catch (error) {
    console.error('❌ Error sending daily motivation:', error);
    res.status(500).json({ error: error.message });
  }
});

// ---------------------------------------------------------
// Start the server
// ---------------------------------------------------------
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`✅ Server is listening on port ${PORT}`);
});