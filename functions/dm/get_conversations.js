/**
 * Direct Messaging: Get Conversations List
 * 
 * Returns list of conversations for the current user
 * (SQL primary, Firestore fallback)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sql = require('mssql');
const { getSqlPool } = require('../utils/sql_pool');

/**
 * Get user's conversation list
 * 
 * @param {Object} data
 * @param {boolean} data.includeArchived - Include archived conversations (default: false)
 * @param {number} data.limit - Max conversations to return (default: 50, max: 100)
 * @param {string} data.beforeTimestamp - For pagination (ISO string)
 * @param {Object} context - Firebase auth context
 */
exports.getConversations = functions.https.onCall(async (data, context) => {
  // Auth check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userUid = context.auth.uid;
  const { includeArchived = false, limit = 50, beforeTimestamp } = data;

  try {
    // ========================================
    // 1. TRY SQL FIRST (PRIMARY)
    // ========================================
    const pool = await getSqlPool();
    const result = await pool.request()
      .input('UserAuthUid', sql.NVarChar(128), userUid)
      .input('IncludeArchived', sql.Bit, includeArchived)
      .input('Limit', sql.Int, Math.min(limit, 100))
      .input('BeforeTimestamp', sql.DateTime, beforeTimestamp ? new Date(beforeTimestamp) : null)
      .execute('sp_DM_GetConversations');

    const conversations = result.recordset.map(row => ({
      conversationId: row.ConversationId,
      otherParticipantUid: row.OtherParticipantAuthUid,
      lastMessage: row.LastMessageText,
      lastMessageAt: row.LastMessageAt ? row.LastMessageAt.toISOString() : null,
      lastMessageType: row.LastMessageType,
      unreadCount: row.UnreadCount,
      isArchived: row.IsArchived,
      createdAt: row.CreatedAt.toISOString(),
      updatedAt: row.UpdatedAt.toISOString(),
    }));

    console.log(`[DM] SQL getConversations successful: ${conversations.length} conversations`);

    return {
      success: true,
      conversations,
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
        .where('participants', 'array-contains', userUid)
        .orderBy('updatedAt', 'desc')
        .limit(Math.min(limit, 100));

      if (beforeTimestamp) {
        query = query.where('updatedAt', '<', new Date(beforeTimestamp));
      }

      const snapshot = await query.get();

      const conversations = snapshot.docs.map(doc => {
        const data = doc.data();
        const otherParticipant = data.participants.find(uid => uid !== userUid);

        return {
          conversationId: doc.id,
          otherParticipantUid: otherParticipant,
          lastMessage: data.lastMessage,
          lastMessageAt: data.lastMessageAt?.toDate().toISOString() || null,
          lastMessageType: data.lastMessageType,
          unreadCount: data[`unreadCount_${userUid}`] || 0,
          isArchived: data[`isArchived_${userUid}`] || false,
          createdAt: data.createdAt?.toDate().toISOString() || null,
          updatedAt: data.updatedAt?.toDate().toISOString() || null,
        };
      });

      console.log(`[DM] Firestore fallback successful: ${conversations.length} conversations`);

      return {
        success: true,
        conversations,
        source: 'firestore',
      };

    } catch (firestoreError) {
      console.error('[DM] Both SQL and Firestore failed:', firestoreError);
      throw new functions.https.HttpsError('internal', 'Failed to retrieve conversations');
    }
  }
});
