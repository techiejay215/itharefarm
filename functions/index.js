const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const { stringify } = require('csv-stringify');

admin.initializeApp();
const db = admin.firestore();

// Configure email transporter – credentials will be set via Firebase Config
const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 465,
  secure: true,
  auth: {
    user: functions.config().email.user,
    pass: functions.config().email.pass,
  },
});

// Helper: export a single collection as CSV
async function exportCollection(collection, userId) {
  const snapshot = await db.collection(collection)
      .where('userId', '==', userId)
      .get();
  if (snapshot.empty) return '';
  const headers = Object.keys(snapshot.docs[0].data());
  const rows = [];
  rows.push(headers);
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    rows.push(headers.map(h => data[h] ?? ''));
  });
  return new Promise((resolve, reject) => {
    stringify(rows, (err, output) => {
      if (err) reject(err);
      else resolve(output);
    });
  });
}

// Main backup function
exports.dailyBackup = functions.https.onRequest(async (req, res) => {
  try {
    const usersSnapshot = await db.collection('users').get();
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      const email = userData.email;
      if (!email) continue;

      const tables = [
        'animals', 'milk_records', 'health_records', 'breeding_records',
        'customers', 'sales', 'feed_inventory', 'feed_usage', 'feed_purchases',
        'expenses', 'other_income', 'vet_records', 'inventory',
        'inventory_purchases', 'notifications', 'users'
      ];

      let csvContent = '';
      for (const table of tables) {
        const csvPart = await exportCollection(table, userId);
        if (csvPart) {
          csvContent += `===== TABLE: ${table} =====\n${csvPart}\n\n`;
        }
      }

      const mailOptions = {
        from: `"Ithare Farm Backup" <${functions.config().email.user}>`,
        to: email,
        subject: 'Daily Farm Backup - Ithare Farm',
        text: 'Please find attached the daily backup of your farm data.',
        attachments: [{
          filename: `ithare_farm_backup_${new Date().toISOString().slice(0,10)}.csv`,
          content: csvContent,
        }],
      };
      await transporter.sendMail(mailOptions);
    }
    res.status(200).send('Backups sent');
  } catch (e) {
    console.error(e);
    res.status(500).send('Error: ' + e.message);
  }
});