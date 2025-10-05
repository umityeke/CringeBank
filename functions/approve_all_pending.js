/**
 * Manual script to approve all pending posts
 * Run with: node approve_all_pending.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json'); // You need to download this from Firebase Console
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function approveAllPending() {
  try {
    console.log('🔍 Fetching pending posts...');
    
    const snapshot = await db
      .collection('cringe_entries')
      .where('status', '==', 'pending')
      .get();

    console.log(`📊 Found ${snapshot.size} pending posts`);

    if (snapshot.empty) {
      console.log('✅ No pending posts to approve');
      return;
    }

    const batch = db.batch();
    let count = 0;

    snapshot.forEach((doc) => {
      batch.update(doc.ref, {
        status: 'approved',
        moderation: {
          action: 'approved',
          moderatorId: 'admin_script',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          note: 'Auto-approved by admin script'
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      count++;
      console.log(`✅ Queued for approval: ${doc.id} - ${doc.data().baslik}`);
    });

    await batch.commit();
    console.log(`\n🎉 Successfully approved ${count} posts!`);

  } catch (error) {
    console.error('❌ Error approving posts:', error);
  } finally {
    process.exit(0);
  }
}

approveAllPending();
