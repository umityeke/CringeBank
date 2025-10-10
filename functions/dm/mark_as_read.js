/**
 * Direct Messaging: Mark Messages as Read
 * 
 * DUAL-WRITE STRATEGY:
 * Update both Firestore and SQL
 */

const functions = require('../regional_functions');
const admin = require('firebase-admin');
const sql = require('mssql');
const { getSqlPool } = require('../utils/sql_pool');
const { sendAlert } = require('../utils/alerts');

/**
 * Mark all unread messages in a conversation as read
 * 
 * @param {Object} data
 * @param {string} data.conversationId - Conversation ID
 * @param {Object} context - Firebase auth context
 */
exports.markAsRead = functions.https.onCall(async (data, context) => {
  // Auth check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const readerUid = context.auth.uid;
  const { conversationId } = data;

  // Validation
  if (!conversationId) {
    throw new functions.https.HttpsError('invalid-argument', 'conversationId is required');
  }

  // Verify user is participant
  const participants = conversationId.split('_');
  if (!participants.includes(readerUid)) {
    throw new functions.https.HttpsError('permission-denied', 'Not a conversation participant');
  }

  try {
    // ========================================
    // 1. UPDATE FIRESTORE (CRITICAL PATH)
    // ========================================
    const messagesRef = admin.firestore()
      .collection('conversations')
      .doc(conversationId)
      .collection('messages');

    // Batch update unread messages
    const unreadSnapshot = await messagesRef
      .where('recipientId', '==', readerUid)
      .where('isRead', '==', false)
      .get();

    const batch = admin.firestore().batch();
    
    unreadSnapshot.docs.forEach(doc => {
      batch.update(doc.ref, {
        isRead: true,
        readAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Reset unread count in conversation
    const conversationRef = admin.firestore()
      .collection('conversations')
      .doc(conversationId);

    batch.update(conversationRef, {
      [`unreadCount_${readerUid}`]: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();

    const markedCount = unreadSnapshot.size;
    console.log(`[DM] Firestore mark-as-read successful: ${markedCount} messages`);

    // ========================================
    // 2. UPDATE SQL (NON-CRITICAL PATH)
    // ========================================
    try {
      const pool = await getSqlPool();
      const result = await pool.request()
        .input('ConversationId', sql.NVarChar(100), conversationId)
        .input('ReaderAuthUid', sql.NVarChar(128), readerUid)
        .execute('sp_DM_MarkAsRead');

      console.log(`[DM] SQL mark-as-read successful: ${result.recordset[0].MessagesMarkedAsRead} messages`);
    } catch (sqlError) {
      console.error('[DM] SQL mark-as-read failed (non-critical):', sqlError);
      await sendAlert('warning', 'DM SQL MarkAsRead Failed', sqlError.message, {
        conversationId,
        readerUid,
      });
    }

    return {
      success: true,
      markedCount,
    };

  } catch (error) {
    console.error('[DM] markAsRead failed:', error);
    throw new functions.https.HttpsError('internal', 'Failed to mark messages as read');
  }
});
