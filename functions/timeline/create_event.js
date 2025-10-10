/**
 * Timeline Create Event
 * 
 * Purpose: Create timeline event with fan-out to followers (SQL + Firestore dual-write)
 * Strategy: Firestore critical path (real-time), SQL non-critical (analytics + fan-out)
 */

const functions = require('../regional_functions');
const admin = require('firebase-admin');
const { getSqlPool } = require('../utils/sql_pool');
const { sendAlert } = require('../utils/alert_service');

/**
 * Create timeline event and fan-out to followers
 * 
 * @param {Object} data
 * @param {string} data.eventPublicId - Event public ID (from Firestore)
 * @param {string} data.actorAuthUid - User who performed the action
 * @param {string} data.eventType - Event type (POST_CREATED, USER_FOLLOWED, etc.)
 * @param {string} data.entityType - Entity type (post, user, comment, etc.)
 * @param {string} data.entityId - Entity ID
 * @param {Object} data.metadata - Additional event metadata
 * @param {boolean} data.fanOutToFollowers - Whether to fan-out to followers (default: true)
 * @param {Object} context - Cloud Functions context
 */
exports.createEvent = async (data, context) => {
  try {
    // Auth check
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const {
      eventPublicId,
      actorAuthUid,
      eventType,
      entityType,
      entityId,
      metadata = {},
      fanOutToFollowers = true,
    } = data;

    // Validation
    if (!eventPublicId) {
      throw new functions.https.HttpsError('invalid-argument', 'eventPublicId is required');
    }

    if (!actorAuthUid) {
      throw new functions.https.HttpsError('invalid-argument', 'actorAuthUid is required');
    }

    if (!eventType) {
      throw new functions.https.HttpsError('invalid-argument', 'eventType is required');
    }

    if (!entityType) {
      throw new functions.https.HttpsError('invalid-argument', 'entityType is required');
    }

    if (!entityId) {
      throw new functions.https.HttpsError('invalid-argument', 'entityId is required');
    }

    // Step 1: Write to Firestore (critical path - real-time updates)
    const firestore = admin.firestore();
    const eventRef = firestore.collection('timeline_events').doc(eventPublicId);
    
    await eventRef.set({
      eventPublicId,
      actorAuthUid,
      eventType,
      entityType,
      entityId,
      metadata,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isDeleted: false,
    });

    console.log(`Timeline event created in Firestore: ${eventPublicId}`);

    // Step 2: Write to SQL (non-critical path - analytics + fan-out)
    let sqlResult = null;
    try {
      const pool = await getSqlPool();
      const metadataJson = metadata ? JSON.stringify(metadata) : null;

      const result = await pool.request()
        .input('EventPublicId', eventPublicId)
        .input('ActorAuthUid', actorAuthUid)
        .input('EventType', eventType)
        .input('EntityType', entityType)
        .input('EntityId', entityId)
        .input('MetadataJson', metadataJson)
        .input('FanOutToFollowers', fanOutToFollowers)
        .execute('sp_Timeline_CreateEvent');

      sqlResult = result.recordset[0];
      console.log(`Timeline event created in SQL: EventId=${sqlResult.EventId}, FannedOut=${sqlResult.FannedOutCount}`);

    } catch (sqlError) {
      console.error('SQL timeline event creation failed:', sqlError);
      
      // Alert but don't fail the request
      await sendAlert('warning', 'Timeline SQL Write Failed', {
        eventPublicId,
        actorAuthUid,
        eventType,
        error: sqlError.message,
      });
    }

    // Return success
    return {
      success: true,
      eventPublicId,
      eventType,
      firestoreWritten: true,
      sqlWritten: sqlResult !== null,
      fannedOutCount: sqlResult ? sqlResult.FannedOutCount : 0,
      createdAt: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Timeline createEvent error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
};
