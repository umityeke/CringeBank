/**
 * Timeline Follow User
 * 
 * Purpose: Follow user and backfill their recent events (SQL + Firestore dual-write)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { getSqlPool } = require('../utils/sql_pool');
const { sendAlert } = require('../utils/alert_service');

/**
 * Follow user
 * 
 * @param {Object} data
 * @param {string} data.followedAuthUid - User being followed
 * @param {Object} context - Cloud Functions context
 */
exports.followUser = async (data, context) => {
  try {
    // Auth check
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const followerAuthUid = context.auth.uid;
    const { followedAuthUid } = data;

    // Validation
    if (!followedAuthUid) {
      throw new functions.https.HttpsError('invalid-argument', 'followedAuthUid is required');
    }

    if (followerAuthUid === followedAuthUid) {
      throw new functions.https.HttpsError('invalid-argument', 'Cannot follow yourself');
    }

    // Step 1: Create follow relationship in Firestore (critical path)
    const firestore = admin.firestore();
    const followRef = firestore.collection('follows')
      .doc(followerAuthUid)
      .collection('following')
      .doc(followedAuthUid);

    await followRef.set({
      followerAuthUid,
      followedAuthUid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
    });

    console.log(`Follow relationship created in Firestore: ${followerAuthUid} -> ${followedAuthUid}`);

    // Step 2: Create follow relationship in SQL (non-critical)
    try {
      const pool = await getSqlPool();
      const result = await pool.request()
        .input('FollowerAuthUid', followerAuthUid)
        .input('FollowedAuthUid', followedAuthUid)
        .execute('sp_Timeline_FollowUser');

      const sqlResult = result.recordset[0];
      console.log(`Follow relationship created in SQL: isNew=${sqlResult.IsNew}`);

    } catch (sqlError) {
      console.error('SQL followUser failed:', sqlError);
      
      await sendAlert('warning', 'Timeline SQL FollowUser Failed', {
        followerAuthUid,
        followedAuthUid,
        error: sqlError.message,
      });
    }

    return {
      success: true,
      followerAuthUid,
      followedAuthUid,
      createdAt: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Timeline followUser error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
};
