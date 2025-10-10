/**
 * Timeline Mark As Read
 * 
 * Purpose: Mark timeline events as read (SQL + Firestore dual-write)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { getSqlPool } = require('../utils/sql_pool');
const { sendAlert } = require('../utils/alert_service');

/**
 * Mark timeline events as read
 * 
 * @param {Object} data
 * @param {string[]} data.eventPublicIds - Array of event public IDs to mark as read (optional)
 * @param {boolean} data.markAllAsRead - Mark all unread events as read (default: false)
 * @param {Object} context - Cloud Functions context
 */
exports.markAsRead = async (data, context) => {
  try {
    // Auth check
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const viewerAuthUid = context.auth.uid;
    const {
      eventPublicIds = [],
      markAllAsRead = false,
    } = data;

    // Validation
    if (!markAllAsRead && eventPublicIds.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Either eventPublicIds or markAllAsRead must be provided');
    }

    // Step 1: Update Firestore (critical path)
    const firestore = admin.firestore();
    const batch = firestore.batch();
    const readAt = admin.firestore.Timestamp.now();

    if (markAllAsRead) {
      // Mark all unread events
      const unreadSnapshot = await firestore.collection('timeline_events')
        .where('viewerAuthUid', '==', viewerAuthUid)
        .where('isRead', '==', false)
        .get();

      unreadSnapshot.docs.forEach(doc => {
        batch.update(doc.ref, {
          isRead: true,
          readAt,
        });
      });

      await batch.commit();
      console.log(`Marked ${unreadSnapshot.size} events as read in Firestore`);

    } else {
      // Mark specific events
      for (const eventPublicId of eventPublicIds) {
        const eventRef = firestore.collection('timeline_events').doc(eventPublicId);
        batch.update(eventRef, {
          isRead: true,
          readAt,
        });
      }

      await batch.commit();
      console.log(`Marked ${eventPublicIds.length} specific events as read in Firestore`);
    }

    // Step 2: Update SQL (non-critical path)
    try {
      const pool = await getSqlPool();
      const eventPublicIdsString = eventPublicIds.join(',');

      const result = await pool.request()
        .input('ViewerAuthUid', viewerAuthUid)
        .input('EventPublicIds', eventPublicIdsString || null)
        .input('MarkAllAsRead', markAllAsRead)
        .execute('sp_Timeline_MarkAsRead');

      const sqlResult = result.recordset[0];
      console.log(`Marked ${sqlResult.MarkedCount} events as read in SQL`);

    } catch (sqlError) {
      console.error('SQL markAsRead failed:', sqlError);
      
      // Alert but don't fail
      await sendAlert('warning', 'Timeline SQL MarkAsRead Failed', {
        viewerAuthUid,
        eventPublicIds: eventPublicIds.slice(0, 10), // Limit to first 10
        markAllAsRead,
        error: sqlError.message,
      });
    }

    return {
      success: true,
      markedCount: markAllAsRead ? 'all' : eventPublicIds.length,
      readAt: readAt.toDate().toISOString(),
    };

  } catch (error) {
    console.error('Timeline markAsRead error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
};
