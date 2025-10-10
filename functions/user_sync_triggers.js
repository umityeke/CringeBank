const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { executeProcedure } = require('./sql_gateway');

const REGION = process.env.USER_SYNC_REGION || 'europe-west1';

/**
 * Firebase Auth onCreate trigger
 * Automatically creates SQL user record when new user signs up
 */
function createOnUserCreatedHandler() {
  return functions
    .region(REGION)
    .auth.user()
    .onCreate(async (user) => {
      const authUid = user.uid;
      const email = user.email || '';
      const displayName = user.displayName || user.email?.split('@')[0] || `user_${authUid.substring(0, 8)}`;
      const username = email.split('@')[0] || `user_${authUid.substring(0, 8)}`;

      functions.logger.info('onUserCreated.trigger', {
        uid: authUid,
        email,
        displayName,
      });

      try {
        const { userId, created } = await executeProcedure(
          'ensureUser',
          {
            authUid,
            email,
            username,
            displayName,
          },
          { skipAuth: true } // Background trigger, no context.auth
        );

        functions.logger.info('onUserCreated.sql.success', {
          uid: authUid,
          sqlUserId: userId,
          created,
        });

        // Initialize Firestore user doc with SQL reference
        const userRef = admin.firestore().collection('users').doc(authUid);
        await userRef.set(
          {
            uid: authUid,
            authUid,
            sqlUserId: userId,
            username,
            displayName,
            email,
            avatar: '👤',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAtUtc: admin.firestore.FieldValue.serverTimestamp(),
            rozetler: ['Yeni Üye'],
            isPremium: false,
            krepScore: 0,
            followersCount: 0,
            followingCount: 0,
          },
          { merge: true }
        );

        functions.logger.info('onUserCreated.firestore.success', {
          uid: authUid,
        });

        return { success: true, sqlUserId: userId };
      } catch (error) {
        functions.logger.error('onUserCreated.error', {
          uid: authUid,
          error: error.message,
          code: error.code,
          stack: error.stack,
        });

        // Non-blocking: Log failure but allow Firebase Auth to proceed
        // Manual sync can be triggered later via ensureSqlUser callable
        return { success: false, error: error.message };
      }
    });
}

/**
 * Firebase Auth onDelete trigger
 * Soft-delete or flag SQL user record when user account is deleted
 */
function createOnUserDeletedHandler() {
  return functions
    .region(REGION)
    .auth.user()
    .onDelete(async (user) => {
      const authUid = user.uid;

      functions.logger.info('onUserDeleted.trigger', {
        uid: authUid,
      });

      try {
        // Mark user as deleted in SQL (you may want to create sp_SoftDeleteUser)
        // For now, just log and clean up Firestore
        await admin.firestore().collection('users').doc(authUid).delete();

        functions.logger.info('onUserDeleted.firestore.success', {
          uid: authUid,
        });

        return { success: true };
      } catch (error) {
        functions.logger.error('onUserDeleted.error', {
          uid: authUid,
          error: error.message,
          stack: error.stack,
        });

        return { success: false, error: error.message };
      }
    });
}

module.exports = {
  createOnUserCreatedHandler,
  createOnUserDeletedHandler,
};
