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
// Debug endpoint – list collections and project ID
// ---------------------------------------------------------
app.get('/debug', async (req, res) => {
  try {
    const projectId = process.env.GCLOUD_PROJECT || 'unknown';
    console.log(`🔍 Debug: Project ID = ${projectId}`);

    const collections = await db.listCollections();
    const collectionIds = collections.map(col => col.id);
    console.log('📂 Collections found:', collectionIds);

    res.json({
      projectId,
      collections: collectionIds,
    });
  } catch (error) {
    console.error('❌ Debug error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ---------------------------------------------------------
// Debug: show project and database info
// ---------------------------------------------------------
app.get('/debug/database', async (req, res) => {
  try {
    const projectId = process.env.GCLOUD_PROJECT || 'unknown';
    const collections = await db.listCollections();
    const collectionIds = collections.map(col => col.id);
    console.log(`🔍 Database debug: project=${projectId}, collections=${collectionIds}`);
    res.json({
      projectId,
      collections: collectionIds,
      databaseId: '(default)'
    });
  } catch (error) {
    console.error('❌ Debug database error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ---------------------------------------------------------
// Debug: list first 5 documents from every collection
// ---------------------------------------------------------
app.get('/debug/all-docs', async (req, res) => {
  try {
    const collections = await db.listCollections();
    const result = {};
    for (const col of collections) {
      const snapshot = await col.limit(5).get();
      result[col.id] = snapshot.docs.map(doc => doc.id);
    }
    res.json(result);
  } catch (error) {
    console.error('❌ Error listing all docs:', error);
    res.status(500).json({ error: error.message });
  }
});

// ---------------------------------------------------------
// Debug: fetch first document from users (to see if any exist)
// ---------------------------------------------------------
app.get('/users-first', async (req, res) => {
  try {
    const snapshot = await db.collection('users').limit(1).get();
    if (snapshot.empty) {
      return res.json({ message: 'No documents in users collection' });
    }
    const doc = snapshot.docs[0];
    res.json({ id: doc.id, data: doc.data() });
  } catch (error) {
    console.error('❌ Error fetching first user:', error);
    res.status(500).json({ error: error.message });
  }
});

// ---------------------------------------------------------
// List all user document IDs
// ---------------------------------------------------------
app.get('/users', async (req, res) => {
  try {
    const snapshot = await db.collection('users').get();
    const ids = snapshot.docs.map(doc => doc.id);
    console.log('👥 User IDs found:', ids);
    res.json({ userIds: ids, count: ids.length });
  } catch (error) {
    console.error('❌ Error reading users:', error);
    res.status(500).json({ error: error.message });
  }
});

// ---------------------------------------------------------
// Fetch a specific user by ID (to test read permissions)
// ---------------------------------------------------------
app.get('/user/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;
    console.log(`🔍 Fetching user: ${userId}`);
    const doc = await db.collection('users').doc(userId).get();
    if (!doc.exists) {
      console.log(`❌ User ${userId} does not exist`);
      return res.status(404).json({ error: 'User not found' });
    }
    console.log(`✅ User ${userId} found:`, doc.data());
    res.json({ id: doc.id, data: doc.data() });
  } catch (error) {
    console.error('❌ Error fetching user:', error);
    res.status(500).json({ error: error.message });
  }
});

// ---------------------------------------------------------
// Endpoint: Send a test notification (with debug logs)
// ---------------------------------------------------------
app.get('/send-test-notification', async (req, res) => {
  try {
    console.log('📤 Fetching all users and tokens...');
    const usersSnapshot = await db.collection('users').get();
    console.log(`📊 Found ${usersSnapshot.size} users`);

    let totalTokens = [];
    
    for (const userDoc of usersSnapshot.docs) {
      console.log(`👤 User: ${userDoc.id}`);

      const tokensSnapshot = await db
        .collection('users')
        .doc(userDoc.id)
        .collection('tokens')
        .get();
      
      const tokens = tokensSnapshot.docs
        .map(doc => doc.data().token)
        .filter(token => token && token.length > 0);
      
      console.log(`🔑 Found ${tokens.length} tokens for user ${userDoc.id}`);
      
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