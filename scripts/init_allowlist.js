/**
 * Initialize allowedMediaHosts config document
 * Run: node scripts/init_allowlist.js
 */

const admin = require('firebase-admin');

// Initialize with application default credentials (uses Firebase project from .firebaserc)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function initAllowlist() {
  console.log('🚀 Creating config/allowedMediaHosts document...\n');
  
  const allowlist = {
    hosts: [
      // Image hosting
      'imgur.com',
      'i.imgur.com',
      
      // Video platforms
      'youtube.com',
      'youtu.be',
      'i.ytimg.com',
      
      // GIFs
      'giphy.com',
      'media.giphy.com',
      'tenor.com',
      'media.tenor.com',
      'c.tenor.com',
      
      // Stock photos
      'unsplash.com',
      'images.unsplash.com',
    ],
    description: 'Allowed domains for external media URLs in direct messages',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: 'system',
  };
  
  try {
    const docRef = db.collection('config').doc('allowedMediaHosts');
    await docRef.set(allowlist);
    
    console.log('✅ Document created successfully!\n');
    console.log('📋 Allowed domains:');
    allowlist.hosts.forEach(host => console.log(`   - ${host}`));
    
    // Verify
    console.log('\n🔍 Verifying...');
    const doc = await docRef.get();
    
    if (doc.exists) {
      console.log('✅ Verification successful!');
      console.log(`📊 Total domains: ${doc.data().hosts.length}`);
    } else {
      console.log('❌ Verification failed - document not found');
    }
    
    console.log('\n✨ Setup complete! External media URLs are now enabled.');
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error creating document:', error.message);
    process.exit(1);
  }
}

// Run
initAllowlist();
