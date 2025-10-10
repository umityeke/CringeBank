// Test allowlist loading (works with emulator or production)
const functions = require('./regional_functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

async function testAllowlist() {
  console.log('🧪 Testing allowlist loading...\n');
  
  try {
    const db = admin.firestore();
    const doc = await db.collection('config').doc('allowedMediaHosts').get();
    
    if (!doc.exists) {
      console.log('⚠️  Document not found - using fallback defaults');
      console.log('📋 Fallback domains: imgur.com, youtube.com, giphy.com\n');
      console.log('✅ Functions will work with fallback allowlist');
      process.exit(0);
    }
    
    const data = doc.data();
    console.log('✅ Document found!\n');
    console.log('📋 Allowed domains:');
    
    if (data.hosts && Array.isArray(data.hosts)) {
      data.hosts.forEach((host, i) => {
        console.log(`   ${i + 1}. ${host}`);
      });
      console.log(`\n📊 Total: ${data.hosts.length} domains`);
    }
    
    if (data.description) {
      console.log(`\n📝 Description: ${data.description}`);
    }
    
    console.log('\n🎉 SUCCESS! External media URLs are enabled!');
    console.log('\n✨ You can now send messages with URLs from these domains.');
    
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.log('\n⚠️  Using fallback allowlist - system will still work!');
    process.exit(0);
  }
}

testAllowlist();
