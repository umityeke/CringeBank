// Quick script to set custom claims using Firebase CLI context
const admin = require('../functions/node_modules/firebase-admin');

// Use Firebase CLI credentials
const projectId = 'cringe-bank'; // Your Firebase project ID

admin.initializeApp({
  projectId: projectId,
});

const uid = process.argv[2];
const remove = process.argv.includes('--remove');

async function setAdminClaim() {
  if (!uid) {
    console.error('❌ Usage: node setAdminClaim.js <uid> [--remove]');
    process.exit(1);
  }

  try {
    console.log('');
    console.log('🛡️  SETTING ADMIN CLAIM');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('');

    const user = await admin.auth().getUser(uid);
    console.log(`📧 Email: ${user.email}`);
    console.log(`👤 Name: ${user.displayName || 'N/A'}`);
    console.log('');

    if (remove) {
      await admin.auth().setCustomUserClaims(uid, {
        admin: false,
        superadmin: false,
        role: null,
      });
      console.log('✅ Admin claims removed');
    } else {
      await admin.auth().setCustomUserClaims(uid, {
        admin: true,
        superadmin: true,
        role: 'superadmin',
        grantedAt: Date.now(),
      });
      console.log('✅ Super admin claims granted!');
      console.log('');
      console.log('📋 Claims:');
      console.log('  - admin: true');
      console.log('  - superadmin: true');
      console.log('  - role: superadmin');
    }

    // Update Firestore
    const userRef = admin.firestore().collection('users').doc(uid);
    const userDoc = await userRef.get();

    if (userDoc.exists) {
      await userRef.update({
        isSuperAdmin: !remove,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`✅ Firestore updated: isSuperAdmin = ${!remove}`);
    }

    // Audit log
    await admin.firestore().collection('admin_audit').add({
      action: remove ? 'removeSuperAdmin' : 'grantSuperAdmin',
      targetUid: uid,
      targetEmail: user.email,
      executedBy: 'cli_script',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Audit log created');

    console.log('');
    console.log('⚠️  User must LOGOUT and LOGIN again for claims to take effect!');
    console.log('');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ Operation completed successfully!');
    console.log('');

  } catch (error) {
    console.error('');
    console.error('❌ Error:', error.message);
    process.exit(1);
  }

  process.exit(0);
}

setAdminClaim();
