// Deploy this function once, call it once, then delete it
// Usage: Call via Firebase Console > Functions > grantSuperAdminOnce

const functions = require('./regional_functions');
const admin = require('firebase-admin');

exports.grantSuperAdminOnce = functions.https.onRequest(async (req, res) => {
  const SUPER_ADMIN_EMAIL = 'umityeke@gmail.com';
  const SECRET_KEY = 'cringe-bank-super-admin-setup-2025'; // Change this!

  // Simple protection - change secret key after use
  const providedKey = req.query.secret || req.body.secret;
  
  if (providedKey !== SECRET_KEY) {
    return res.status(403).json({
      error: 'Invalid secret key',
      hint: 'Add ?secret=YOUR_SECRET to URL'
    });
  }

  try {
    // Find user by email
    const user = await admin.auth().getUserByEmail(SUPER_ADMIN_EMAIL);
    const uid = user.uid;

    console.log(`Found user: ${user.email} (${uid})`);

    // Set custom claims
    await admin.auth().setCustomUserClaims(uid, {
      admin: true,
      superadmin: true,
      role: 'superadmin',
      grantedAt: Date.now(),
    });

    console.log('Custom claims set!');

    // Update Firestore
    const userRef = admin.firestore().collection('users').doc(uid);
    const userDoc = await userRef.get();

    if (userDoc.exists) {
      await userRef.update({
        isSuperAdmin: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('Firestore user doc updated');
    } else {
      console.log('User doc not found in Firestore');
    }

    // Create audit log
    await admin.firestore().collection('admin_audit').add({
      action: 'grantSuperAdmin',
      targetUid: uid,
      targetEmail: user.email,
      executedBy: 'deploy_function',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('Audit log created');

    return res.json({
      success: true,
      message: 'Super admin granted successfully!',
      email: user.email,
      uid: uid,
      claims: {
        admin: true,
        superadmin: true,
        role: 'superadmin'
      },
      important: 'User must LOGOUT and LOGIN again for claims to take effect!'
    });

  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({
      error: error.message,
      code: error.code
    });
  }
});
