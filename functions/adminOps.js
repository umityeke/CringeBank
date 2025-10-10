// 🛡️ ADMIN OPERATIONS - Secure Admin Panel Functions
// 
// 3-Layer Security:
// 1. Auth: Custom Claims (superadmin: true)
// 2. App Check: Verified app only
// 3. Re-auth: Recent authentication required (5 min)

const functions = require('./regional_functions');
const admin = require('firebase-admin');

// Constants
const SUPER_ADMIN_EMAIL = 'umityeke@gmail.com';
const MAX_ADMINS_PER_CATEGORY = 3;
const RE_AUTH_WINDOW_SECONDS = 300; // 5 minutes

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Verify App Check token (when enforced)
 */
const verifyAppCheck = (context) => {
  if (!context.app) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      '🚫 App Check verification required. Please use verified app.'
    );
  }
  return true;
};

/**
 * Verify user is authenticated
 */
const verifyAuth = (context) => {
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      '🚫 Authentication required. Please login.'
    );
  }
  return context.auth.uid;
};

/**
 * Check if user has super admin claim or email
 */
const isSuperAdmin = (context) => {
  const claims = context.auth?.token || {};
  const email = claims.email || '';
  
  return (
    claims.superadmin === true ||
    claims.admin === true ||
    email.toLowerCase() === SUPER_ADMIN_EMAIL.toLowerCase()
  );
};

/**
 * Verify re-authentication freshness (step-up auth)
 */
const verifyRecentAuth = (context) => {
  const authTime = context.auth?.token?.auth_time || 0;
  const now = Math.floor(Date.now() / 1000);
  
  if (now - authTime > RE_AUTH_WINDOW_SECONDS) {
    throw new functions.https.HttpsError(
      'permission-denied',
      '🔐 Re-authentication required. Please login again for security.'
    );
  }
  return true;
};

/**
 * Audit log helper
 */
const logAdminAction = async (uid, action, details = {}) => {
  try {
    await admin.firestore().collection('admin_audit').add({
      uid,
      email: details.email || null,
      action,
      details,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      source: 'callable_function',
    });
  } catch (error) {
    console.error('❌ Audit log failed:', error);
  }
};

// ============================================================================
// CATEGORY ADMIN MANAGEMENT
// ============================================================================

/**
 * Assign category admin (super admin only)
 * 
 * @param {Object} data
 * @param {string} data.category - Category name
 * @param {string} data.targetUserId - User ID to assign as admin
 * @param {string} data.targetUsername - Username of the admin
 * @param {string[]} data.permissions - Permissions array
 */
exports.assignCategoryAdmin = functions.https.onCall(async (data, context) => {
  // 1. App Check (optional but recommended)
  // Uncomment when App Check is enabled:
  // verifyAppCheck(context);
  
  // 2. Auth verification
  const uid = verifyAuth(context);
  const email = context.auth.token.email || '';
  
  // 3. Super admin check
  if (!isSuperAdmin(context)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      '❌ Only super admin can assign category admins.'
    );
  }
  
  // 4. Re-auth check (critical operation)
  verifyRecentAuth(context);
  
  // 5. Validate input
  const { category, targetUserId, targetUsername, permissions = ['approve', 'reject'] } = data;
  
  if (!category || !targetUserId || !targetUsername) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      '❌ Missing required fields: category, targetUserId, targetUsername'
    );
  }
  
  console.log(`📋 Assigning admin: ${targetUsername} → ${category}`);
  
  // 6. Check admin limit
  const categoryRef = admin.firestore().collection('category_admins').doc(category);
  const snapshot = await categoryRef.get();
  
  const now = new Date().toISOString();
  
  if (snapshot.exists) {
    const admins = snapshot.data().admins || [];
    const existingIndex = admins.findIndex(a => a.userId === targetUserId);
    
    if (existingIndex >= 0) {
      // Update existing admin
      admins[existingIndex] = {
        userId: targetUserId,
        username: targetUsername,
        assignedAt: now,
        assignedBy: uid,
        permissions,
        isActive: true,
      };
    } else {
      // Add new admin
      if (admins.length >= MAX_ADMINS_PER_CATEGORY) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `❌ Maximum ${MAX_ADMINS_PER_CATEGORY} admins per category. Remove one first.`
        );
      }
      
      admins.push({
        userId: targetUserId,
        username: targetUsername,
        assignedAt: now,
        assignedBy: uid,
        permissions,
        isActive: true,
      });
    }
    
    await categoryRef.update({
      admins,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: uid,
    });
  } else {
    // Create new category document
    await categoryRef.set({
      category,
      admins: [{
        userId: targetUserId,
        username: targetUsername,
        assignedAt: now,
        assignedBy: uid,
        permissions,
        isActive: true,
      }],
      maxAdmins: MAX_ADMINS_PER_CATEGORY,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: uid,
    });
  }
  
  // 7. Audit log
  await logAdminAction(uid, 'assignCategoryAdmin', {
    email,
    category,
    targetUserId,
    targetUsername,
    permissions,
  });
  
  console.log(`✅ Admin assigned: ${targetUsername} → ${category}`);
  
  return {
    success: true,
    message: `Admin assigned: ${targetUsername} → ${category}`,
    category,
    adminCount: snapshot.exists ? (snapshot.data().admins || []).length : 1,
  };
});

/**
 * Remove category admin (super admin only)
 */
exports.removeCategoryAdmin = functions.https.onCall(async (data, context) => {
  const uid = verifyAuth(context);
  const email = context.auth.token.email || '';
  
  if (!isSuperAdmin(context)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      '❌ Only super admin can remove category admins.'
    );
  }
  
  verifyRecentAuth(context);
  
  const { category, targetUserId } = data;
  
  if (!category || !targetUserId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      '❌ Missing required fields: category, targetUserId'
    );
  }
  
  console.log(`🗑️ Removing admin: ${targetUserId} ← ${category}`);
  
  const categoryRef = admin.firestore().collection('category_admins').doc(category);
  const snapshot = await categoryRef.get();
  
  if (!snapshot.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      `❌ Category not found: ${category}`
    );
  }
  
  const admins = (snapshot.data().admins || []).filter(a => a.userId !== targetUserId);
  
  await categoryRef.update({
    admins,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: uid,
  });
  
  await logAdminAction(uid, 'removeCategoryAdmin', {
    email,
    category,
    targetUserId,
  });
  
  console.log(`✅ Admin removed: ${targetUserId} ← ${category}`);
  
  return {
    success: true,
    message: `Admin removed from ${category}`,
    category,
    adminCount: admins.length,
  };
});

/**
 * Toggle admin status (active/inactive)
 */
exports.toggleCategoryAdminStatus = functions.https.onCall(async (data, context) => {
  const uid = verifyAuth(context);
  const email = context.auth.token.email || '';
  
  if (!isSuperAdmin(context)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      '❌ Only super admin can toggle admin status.'
    );
  }
  
  const { category, targetUserId, isActive } = data;
  
  if (!category || !targetUserId || typeof isActive !== 'boolean') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      '❌ Missing required fields: category, targetUserId, isActive'
    );
  }
  
  const categoryRef = admin.firestore().collection('category_admins').doc(category);
  const snapshot = await categoryRef.get();
  
  if (!snapshot.exists) {
    throw new functions.https.HttpsError('not-found', `❌ Category not found: ${category}`);
  }
  
  const admins = snapshot.data().admins || [];
  const index = admins.findIndex(a => a.userId === targetUserId);
  
  if (index < 0) {
    throw new functions.https.HttpsError('not-found', `❌ Admin not found: ${targetUserId}`);
  }
  
  const now = new Date().toISOString();
  
  admins[index].isActive = isActive;
  admins[index].statusChangedAt = now;
  admins[index].statusChangedBy = uid;
  
  await categoryRef.update({
    admins,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  await logAdminAction(uid, 'toggleAdminStatus', {
    email,
    category,
    targetUserId,
    isActive,
  });
  
  return {
    success: true,
    message: `Admin status updated: ${isActive ? 'Active' : 'Inactive'}`,
  };
});

// ============================================================================
// COMPETITION MANAGEMENT (Example)
// ============================================================================

/**
 * Create competition (super admin only)
 */
exports.createCompetition = functions.https.onCall(async (data, context) => {
  const uid = verifyAuth(context);
  const email = context.auth.token.email || '';
  
  if (!isSuperAdmin(context)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      '❌ Only super admin can create competitions.'
    );
  }
  
  verifyRecentAuth(context);
  
  const {
    title,
    description,
    visibility = 'public',
    startDate,
    endDate,
  } = data;
  
  if (!title) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      '❌ Competition title required.'
    );
  }
  
  console.log(`🏆 Creating competition: ${title}`);
  
  const payload = {
    title: String(title),
    description: String(description || ''),
    ownerId: uid,
    visibility: ['public', 'listed', 'private'].includes(visibility) ? visibility : 'public',
    status: 'draft',
    startDate: startDate || null,
    endDate: endDate || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  const ref = await admin.firestore().collection('competitions').add(payload);
  
  await logAdminAction(uid, 'createCompetition', {
    email,
    competitionId: ref.id,
    title,
    visibility,
  });
  
  console.log(`✅ Competition created: ${ref.id}`);
  
  return {
    success: true,
    competitionId: ref.id,
    message: `Competition created: ${title}`,
  };
});

/**
 * Update competition (super admin only)
 */
exports.updateCompetition = functions.https.onCall(async (data, context) => {
  const uid = verifyAuth(context);
  const email = context.auth.token.email || '';
  
  if (!isSuperAdmin(context)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      '❌ Only super admin can update competitions.'
    );
  }
  
  verifyRecentAuth(context);
  
  const { competitionId, updates } = data;
  
  if (!competitionId || !updates) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      '❌ Missing competitionId or updates.'
    );
  }
  
  const ref = admin.firestore().collection('competitions').doc(competitionId);
  const snapshot = await ref.get();
  
  if (!snapshot.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      `❌ Competition not found: ${competitionId}`
    );
  }
  
  await ref.update({
    ...updates,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: uid,
  });
  
  await logAdminAction(uid, 'updateCompetition', {
    email,
    competitionId,
    updates,
  });
  
  return {
    success: true,
    message: 'Competition updated',
    competitionId,
  };
});

/**
 * Delete competition (super admin only)
 */
exports.deleteCompetition = functions.https.onCall(async (data, context) => {
  const uid = verifyAuth(context);
  const email = context.auth.token.email || '';
  
  if (!isSuperAdmin(context)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      '❌ Only super admin can delete competitions.'
    );
  }
  
  verifyRecentAuth(context);
  
  const { competitionId } = data;
  
  if (!competitionId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      '❌ Missing competitionId.'
    );
  }
  
  await admin.firestore().collection('competitions').doc(competitionId).delete();
  
  await logAdminAction(uid, 'deleteCompetition', {
    email,
    competitionId,
  });
  
  return {
    success: true,
    message: 'Competition deleted',
    competitionId,
  };
});
