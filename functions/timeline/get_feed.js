/**
 * Timeline Get User Feed
 * 
 * Purpose: Get user's timeline feed (SQL primary, Firestore fallback)
 * Strategy: SQL for fast pagination, Firestore for reliability
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { getSqlPool } = require('../utils/sql_pool');

/**
 * Get user's timeline feed
 * 
 * @param {Object} data
 * @param {number} data.limit - Number of events to fetch (max 100)
 * @param {number} data.beforeTimelineId - Timeline ID for pagination (optional)
 * @param {boolean} data.includeRead - Include already-read events (default: true)
 * @param {boolean} data.includeHidden - Include hidden events (default: false)
 * @param {Object} context - Cloud Functions context
 */
exports.getUserFeed = async (data, context) => {
  try {
    // Auth check
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const viewerAuthUid = context.auth.uid;
    const {
      limit = 50,
      beforeTimelineId = null,
      includeRead = true,
      includeHidden = false,
    } = data;

    // Validation
    if (limit > 100) {
      throw new functions.https.HttpsError('invalid-argument', 'Limit cannot exceed 100');
    }

    // Try SQL first (primary source)
    try {
      const pool = await getSqlPool();
      const result = await pool.request()
        .input('ViewerAuthUid', viewerAuthUid)
        .input('Limit', limit)
        .input('BeforeTimelineId', beforeTimelineId)
        .input('IncludeRead', includeRead)
        .input('IncludeHidden', includeHidden)
        .execute('sp_Timeline_GetUserFeed');

      const events = result.recordset.map(row => ({
        timelineId: row.TimelineId,
        eventPublicId: row.EventPublicId,
        eventId: row.EventId,
        actorAuthUid: row.ActorAuthUid,
        eventType: row.EventType,
        entityType: row.EntityType,
        entityId: row.EntityId,
        isRead: row.IsRead,
        isHidden: row.IsHidden,
        createdAt: row.CreatedAt.toISOString(),
        readAt: row.ReadAt ? row.ReadAt.toISOString() : null,
        metadata: row.MetadataJson ? JSON.parse(row.MetadataJson) : {},
      }));

      return {
        success: true,
        events,
        source: 'sql',
        count: events.length,
      };

    } catch (sqlError) {
      console.error('SQL getUserFeed failed, falling back to Firestore:', sqlError);

      // Fallback to Firestore
      const firestore = admin.firestore();
      let query = firestore.collection('timeline_events')
        .where('viewerAuthUid', '==', viewerAuthUid)
        .orderBy('createdAt', 'desc')
        .limit(limit);

      if (beforeTimelineId) {
        const beforeDoc = await firestore.collection('timeline_events').doc(beforeTimelineId).get();
        if (beforeDoc.exists) {
          query = query.startAfter(beforeDoc);
        }
      }

      const snapshot = await query.get();
      const events = snapshot.docs.map(doc => {
        const data = doc.data();
        return {
          timelineId: doc.id,
          eventPublicId: data.eventPublicId || doc.id,
          actorAuthUid: data.actorAuthUid,
          eventType: data.eventType,
          entityType: data.entityType,
          entityId: data.entityId,
          isRead: data.isRead || false,
          isHidden: data.isHidden || false,
          createdAt: data.createdAt?.toDate?.().toISOString() || new Date().toISOString(),
          readAt: data.readAt?.toDate?.().toISOString() || null,
          metadata: data.metadata || {},
        };
      });

      return {
        success: true,
        events,
        source: 'firestore',
        count: events.length,
      };
    }

  } catch (error) {
    console.error('Timeline getUserFeed error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
};
