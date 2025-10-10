/**
 * Direct Messaging: Get Messages
 * 
 * HYBRID STRATEGY:
 * 1. Read from SQL (primary source - faster, more flexible queries)
 * 2. Fallback to Firestore if SQL fails (reliability)
 * 
 * Real-time updates still come from Firestore listeners in Flutter
 */

const functions = require('../regional_functions');
const admin = require('firebase-admin');
const sql = require('mssql');
const { getSqlPool } = require('../utils/sql_pool');

/**
 * Get messages for a conversation
 * 
 * @param {Object} data
 * @param {string} data.conversationId - Conversation ID (uid1_uid2 sorted)
 * @param {number} data.limit - Max messages to return (default: 50, max: 100)
 * @param {number} data.beforeMessageId - For pagination (load older messages)
 * @param {Object} context - Firebase auth context
 */
exports.getMessages = functions.https.onCall(async (data, context) => {
  // Auth check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const requestorUid = context.auth.uid;
  const { conversationId, limit = 50, beforeMessageId } = data;

  // Validation
  if (!conversationId) {
    throw new functions.https.HttpsError('invalid-argument', 'conversationId is required');
  }

  // Verify user is participant
  const participants = conversationId.split('_');
  if (!participants.includes(requestorUid)) {
    throw new functions.https.HttpsError('permission-denied', 'Not a conversation participant');
  }

  try {
    // ========================================
    // 1. TRY SQL FIRST (PRIMARY)
    // ========================================
    const pool = await getSqlPool();
    const result = await pool.request()
      .input('ConversationId', sql.NVarChar(100), conversationId)
      .input('RequestorAuthUid', sql.NVarChar(128), requestorUid)
      .input('Limit', sql.Int, Math.min(limit, 100))
      .input('BeforeMessageId', sql.BigInt, beforeMessageId || null)
      .execute('sp_DM_GetMessages');

    // Transform SQL result to match Firestore format
    const messages = result.recordset.map(row => ({
      id: row.MessagePublicId,
      messageId: row.MessageId,
      senderId: row.SenderAuthUid,
      recipientId: row.RecipientAuthUid,
      text: row.MessageText,
      type: row.MessageType,
      imageUrl: row.ImageUrl,
      voiceUrl: row.VoiceUrl,
      voiceDurationSec: row.VoiceDurationSec,
      isRead: row.IsRead,
      createdAt: row.CreatedAt.toISOString(),
      readAt: row.ReadAt ? row.ReadAt.toISOString() : null,
    }));

    console.log(`[DM] SQL read successful: ${messages.length} messages`);

    return {
      success: true,
      messages,
      source: 'sql',
    };

  } catch (sqlError) {
    console.error('[DM] SQL read failed, falling back to Firestore:', sqlError);

    // ========================================
    // 2. FALLBACK TO FIRESTORE (RELIABILITY)
    // ========================================
    try {
      let query = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('isDeleted', '==', false)
        .orderBy('createdAt', 'desc')
        .limit(Math.min(limit, 100));

      // Pagination (Firestore doesn't use numeric IDs)
      if (beforeMessageId) {
        const beforeDoc = await admin.firestore()
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(beforeMessageId.toString())
          .get();
        
        if (beforeDoc.exists) {
          query = query.startAfter(beforeDoc);
        }
      }

      const snapshot = await query.get();

      const messages = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        createdAt: doc.data().createdAt?.toDate().toISOString() || null,
        readAt: doc.data().readAt?.toDate().toISOString() || null,
      }));

      console.log(`[DM] Firestore fallback successful: ${messages.length} messages`);

      return {
        success: true,
        messages,
        source: 'firestore',
      };

    } catch (firestoreError) {
      console.error('[DM] Both SQL and Firestore failed:', firestoreError);
      throw new functions.https.HttpsError('internal', 'Failed to retrieve messages');
    }
  }
});
