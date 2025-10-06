// Quick check if allowlist exists
// Run from functions folder: node check_allowlist.js

const admin = require('firebase-admin');

// Use existing Firebase app if available
if (!admin.apps.length) {
  try {
    admin.initializeApp();
  } catch (e) {
    console.log('⚠️  Could not initialize admin, trying project ID...');
    admin.initializeApp({
      projectId: 'cringe-bank',
    });
  }
}

const db = admin.firestore();

async function checkAllowlist() {
  try {
    console.log('🔍 Checking config/allowedMediaHosts...\n');
    
    const doc = await db.collection('config').doc('allowedMediaHosts').get();
    
    if (!doc.exists) {
      console.log('❌ Document NOT FOUND!');
      console.log('\n📝 Please create it in Firebase Console:');
      console.log('   Collection: config');
      console.log('   Document: allowedMediaHosts');
      console.log('   Field: hosts (array with domains)');
      process.exit(1);
    }
    
    const data = doc.data();
    console.log('✅ Document EXISTS!\n');
    console.log('📋 Current allowlist:');
    
    if (data.hosts && Array.isArray(data.hosts)) {
      console.log(`   Total domains: ${data.hosts.length}\n`);
      data.hosts.forEach((host, index) => {
        console.log(`   ${index + 1}. ${host}`);
      });
    } else {
      console.log('   ⚠️  "hosts" field is missing or not an array!');
    }
    
    console.log('\n✨ System is ready for external media URLs!');
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.log('\n💡 Tip: Make sure you have Firebase credentials set up.');
    console.log('   Or check the document manually in Firebase Console.');
    process.exit(1);
  }
}

checkAllowlist();
