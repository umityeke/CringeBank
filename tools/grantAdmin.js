#!/usr/bin/env node

/**
 * 🛡️ GRANT SUPER ADMIN - Custom Claims Script
 * 
 * Bu script SADECE backend'den çalıştırılmalı!
 * Client'tan asla custom claim atanmamalı.
 * 
 * Usage:
 *   node grantAdmin.js <user-uid> [--remove]
 * 
 * Example:
 *   node grantAdmin.js abc123xyz456
 *   node grantAdmin.js abc123xyz456 --remove
 * 
 * Requirements:
 *   - Firebase Admin SDK service account key
 *   - Set GOOGLE_APPLICATION_CREDENTIALS env variable
 */

const admin = require('../functions/node_modules/firebase-admin');

// Initialize Firebase Admin SDK
// Option 1: Use service account key file
// const serviceAccount = require('./path/to/serviceAccountKey.json');
// admin.initializeApp({
//   credential: admin.credential.cert(serviceAccount)
// });

// Option 2: Use default credentials (when running in Cloud Functions/GCP)
admin.initializeApp();

const SUPER_ADMIN_EMAIL = 'umityeke@gmail.com';

/**
 * Grant super admin custom claims
 */
async function grantSuperAdmin(uid) {
  try {
    console.log(`🔍 Fetching user: ${uid}`);
    const user = await admin.auth().getUser(uid);
    
    console.log(`📧 User email: ${user.email}`);
    console.log(`👤 User display name: ${user.displayName || 'N/A'}`);
    
    // Verify email matches super admin
    if (user.email?.toLowerCase() !== SUPER_ADMIN_EMAIL.toLowerCase()) {
      console.warn(`⚠️  WARNING: This user email (${user.email}) is not the super admin email (${SUPER_ADMIN_EMAIL})`);
      console.log('Proceeding anyway...');
    }
    
    // Set custom claims
    await admin.auth().setCustomUserClaims(uid, {
      admin: true,
      superadmin: true,
      role: 'superadmin',
      grantedAt: Date.now(),
    });
    
    console.log('✅ Super admin claims granted successfully!');
    console.log('');
    console.log('📋 Granted claims:');
    console.log('  - admin: true');
    console.log('  - superadmin: true');
    console.log('  - role: superadmin');
    console.log('');
    console.log('⚠️  User must logout and login again for claims to take effect!');
    
    // Update Firestore user document
    const userRef = admin.firestore().collection('users').doc(uid);
    const userDoc = await userRef.get();
    
    if (userDoc.exists) {
      await userRef.update({
        isSuperAdmin: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('✅ Firestore user document updated with isSuperAdmin: true');
    } else {
      console.log('⚠️  User document not found in Firestore');
    }
    
    // Add to admin_audit
    await admin.firestore().collection('admin_audit').add({
      action: 'grantSuperAdmin',
      targetUid: uid,
      targetEmail: user.email,
      executedBy: 'backend_script',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('✅ Audit log created');
    
  } catch (error) {
    console.error('❌ Error granting super admin:', error.message);
    throw error;
  }
}

/**
 * Remove super admin custom claims
 */
async function removeSuperAdmin(uid) {
  try {
    console.log(`🔍 Fetching user: ${uid}`);
    const user = await admin.auth().getUser(uid);
    
    console.log(`📧 User email: ${user.email}`);
    
    // Remove custom claims
    await admin.auth().setCustomUserClaims(uid, {
      admin: false,
      superadmin: false,
      role: null,
    });
    
    console.log('✅ Super admin claims removed successfully!');
    
    // Update Firestore user document
    const userRef = admin.firestore().collection('users').doc(uid);
    const userDoc = await userRef.get();
    
    if (userDoc.exists) {
      await userRef.update({
        isSuperAdmin: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('✅ Firestore user document updated with isSuperAdmin: false');
    }
    
    // Add to admin_audit
    await admin.firestore().collection('admin_audit').add({
      action: 'removeSuperAdmin',
      targetUid: uid,
      targetEmail: user.email,
      executedBy: 'backend_script',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('✅ Audit log created');
    
  } catch (error) {
    console.error('❌ Error removing super admin:', error.message);
    throw error;
  }
}

/**
 * List all users with admin claims
 */
async function listAdmins() {
  try {
    console.log('🔍 Searching for admin users...');
    console.log('');
    
    let adminCount = 0;
    let pageToken;
    
    do {
      const listResult = await admin.auth().listUsers(1000, pageToken);
      
      for (const user of listResult.users) {
        if (user.customClaims?.admin === true || user.customClaims?.superadmin === true) {
          adminCount++;
          console.log(`👑 Admin #${adminCount}`);
          console.log(`  UID: ${user.uid}`);
          console.log(`  Email: ${user.email}`);
          console.log(`  Display Name: ${user.displayName || 'N/A'}`);
          console.log(`  Claims:`, user.customClaims);
          console.log('');
        }
      }
      
      pageToken = listResult.pageToken;
    } while (pageToken);
    
    console.log(`✅ Total admins found: ${adminCount}`);
    
  } catch (error) {
    console.error('❌ Error listing admins:', error.message);
    throw error;
  }
}

// ============================================================================
// CLI
// ============================================================================

async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    console.log('');
    console.log('🛡️  GRANT SUPER ADMIN - Custom Claims Script');
    console.log('');
    console.log('Usage:');
    console.log('  node grantAdmin.js <user-uid>          Grant super admin');
    console.log('  node grantAdmin.js <user-uid> --remove Remove super admin');
    console.log('  node grantAdmin.js --list              List all admins');
    console.log('');
    console.log('Examples:');
    console.log('  node grantAdmin.js abc123xyz456');
    console.log('  node grantAdmin.js abc123xyz456 --remove');
    console.log('  node grantAdmin.js --list');
    console.log('');
    process.exit(0);
  }
  
  if (args.includes('--list')) {
    await listAdmins();
    process.exit(0);
  }
  
  const uid = args[0];
  const remove = args.includes('--remove');
  
  if (!uid) {
    console.error('❌ Missing user UID!');
    console.log('Usage: node grantAdmin.js <user-uid>');
    process.exit(1);
  }
  
  console.log('');
  console.log('🛡️  GRANT SUPER ADMIN SCRIPT');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');
  
  if (remove) {
    await removeSuperAdmin(uid);
  } else {
    await grantSuperAdmin(uid);
  }
  
  console.log('');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('✅ Operation completed successfully!');
  console.log('');
  
  process.exit(0);
}

// Run
main().catch((error) => {
  console.error('');
  console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.error('❌ FATAL ERROR');
  console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.error(error);
  console.error('');
  process.exit(1);
});
