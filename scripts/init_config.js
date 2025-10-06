/**
 * Initialize Firestore Config Collection
 * Creates allowedMediaHosts document with default allowlist
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Download from Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function initializeConfig() {
  console.log('🚀 Initializing Firestore config collection...');
  
  try {
    // Create allowedMediaHosts document
    const configRef = db.collection('config').doc('allowedMediaHosts');
    
    const allowlist = {
      hosts: [
        'imgur.com',
        'i.imgur.com',
        'youtube.com',
        'youtu.be',
        'i.ytimg.com',
        'giphy.com',
        'media.giphy.com',
        'tenor.com',
        'media.tenor.com',
        'c.tenor.com',
        'cdnjs.cloudflare.com',
        'unsplash.com',
        'images.unsplash.com',
      ],
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: 'system',
    };
    
    await configRef.set(allowlist);
    
    console.log('✅ Config document created successfully!');
    console.log('📋 Allowed domains:', allowlist.hosts);
    
    // Verify
    const doc = await configRef.get();
    if (doc.exists) {
      console.log('✅ Verification successful!');
      console.log('📄 Document data:', doc.data());
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

initializeConfig();
