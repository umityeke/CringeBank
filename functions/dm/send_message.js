/**
 * Direct Messaging: Send Message
 * 
 * DUAL-WRITE STRATEGY:
 * 1. Write to Firestore (for real-time listeners - immediate UI update)
 * 2. Write to SQL (for historical queries, analytics, search)
 * 
 * If SQL write fails, log error but don't fail the request
 * (Firestore is source of truth for real-time)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sql = require('mssql');
const { getSqlPool } = require('../utils/sql_pool');
const { sendAlert } = require('../utils/alerts');
const { v4: uuidv4 } = require('uuid');

/**
 * Send a message between users
 * 
 * @param {Object} data
 * @param {string} data.recipientUid - Recipient's Auth UID
 * @param {string} data.messageText - Message text content (optional if image/voice)
 * @param {string} data.messageType - Message type: TEXT, IMAGE, VOICE (default: TEXT)
 * @param {string} data.imageUrl - Image URL (for IMAGE type)
 * @param {string} data.voiceUrl - Voice recording URL (for VOICE type)
 * @param {number} data.voiceDurationSec - Voice duration in seconds
 * @param {Object} context - Firebase auth context
 */
exports.sendMessage = functions.https.onCall(async (data, context) => {
  // Auth check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const senderUid = context.auth.uid;
  const { recipientUid, messageText, messageType = 'TEXT', imageUrl, voiceUrl, voiceDurationSec } = data;

  // Validation
  if (!recipientUid) {
    throw new functions.https.HttpsError('invalid-argument', 'recipientUid is required');
  }

  if (senderUid === recipientUid) {
    throw new functions.https.HttpsError('invalid-argument', 'Cannot send message to yourself');
  }

  if (!messageText && !imageUrl && !voiceUrl) {
    throw new functions.https.HttpsError('invalid-argument', 'Message must have text, image, or voice content');
  }

  // Generate IDs
  const messageId = uuidv4();
  const conversationId = [senderUid, recipientUid].sort().join('_');

  const messageData = {
    senderId: senderUid,
    recipientId: recipientUid,
    text: messageText || null,
    type: messageType,
    imageUrl: imageUrl || null,
    voiceUrl: voiceUrl || null,
    voiceDurationSec: voiceDurationSec || null,
    isRead: false,
    isDeleted: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    // ========================================
    // 1. WRITE TO FIRESTORE (CRITICAL PATH)
    // ========================================
    const firestoreWritePromises = [];

    // Write message to Firestore
    firestoreWritePromises.push(
      admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .set(messageData)
    );

    // Update conversation metadata
    const conversationUpdate = {
      participants: [senderUid, recipientUid],
      lastMessage: messageText || (messageType === 'IMAGE' ? '📷 Image' : '🎤 Voice message'),
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageType: messageType,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Increment recipient's unread count
    conversationUpdate[`unreadCount_${recipientUid}`] = admin.firestore.FieldValue.increment(1);

    firestoreWritePromises.push(
      admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .set(conversationUpdate, { merge: true })
    );

    // Execute Firestore writes
    await Promise.all(firestoreWritePromises);

    // ========================================
    // 2. WRITE TO SQL (NON-CRITICAL PATH)
    // ========================================
    try {
      const pool = await getSqlPool();
      await pool.request()
        .input('MessagePublicId', sql.NVarChar(50), messageId)
        .input('SenderAuthUid', sql.NVarChar(128), senderUid)
        .input('RecipientAuthUid', sql.NVarChar(128), recipientUid)
        .input('MessageText', sql.NVarChar(sql.MAX), messageText)
        .input('MessageType', sql.NVarChar(20), messageType)
        .input('ImageUrl', sql.NVarChar(500), imageUrl)
        .input('VoiceUrl', sql.NVarChar(500), voiceUrl)
        .input('VoiceDurationSec', sql.Int, voiceDurationSec)
        .execute('sp_DM_SendMessage');

      console.log(`[DM] SQL write successful: ${messageId}`);
    } catch (sqlError) {
      // SQL write failed - log and alert, but don't fail the request
      console.error('[DM] SQL write failed (non-critical):', sqlError);
      await sendAlert('warning', 'DM SQL Write Failed', sqlError.message, {
        messageId,
        senderUid,
        recipientUid,
        conversationId,
      });
    }

    // ========================================
    // 3. SEND FCM NOTIFICATION (OPTIONAL)
    // ========================================
    // TODO: Send push notification to recipient if they're offline
    // This will be implemented in Faz 2.3 (Notifications)

    // Return success
    return {
      success: true,
      messageId,
      conversationId,
      createdAt: new Date().toISOString(),
    };

  } catch (error) {
    console.error('[DM] sendMessage failed:', error);
    
    // Firestore write failed - critical error
    throw new functions.https.HttpsError('internal', 'Failed to send message', error.message);
  }
});
