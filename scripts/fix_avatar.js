const admin = require('firebase-admin');
const serviceAccount = require('../firebase_sdk/cringebank-firebase-adminsdk-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixAvatar() {
  const userId = 'nXszUFPvwlhAw4avJoCy9SCAZSg2';
  
  try {
    console.log('Updating avatar for user:', userId);
    
    await db.collection('users').doc(userId).update({
      avatar: ''
    });
    
    console.log('✅ Avatar updated to empty string');
    
    // Also delete the entry with emoji avatar
    const entryId = '1759519133993';
    console.log('Deleting entry with emoji avatar:', entryId);
    
    const entrySnap = await db.collectionGroup('entries')
      .where('id', '==', entryId)
      .limit(1)
      .get();

    if (!entrySnap.empty) {
      await entrySnap.docs[0].ref.delete();
      console.log('✅ Entry deleted');
    } else {
      console.log('ℹ️ Entry already deleted');
    }
    
    // Verify user
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    console.log('Current avatar value:', JSON.stringify(userData.avatar));
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit(0);
}

fixAvatar();
