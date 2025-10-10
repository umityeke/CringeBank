const functions = require('firebase-functions');
const admin = require('firebase-admin');
const https = require('https');
const http = require('http');
const { URL } = require('url');

// ====================================================================
// CONFIGURATION CONSTANTS
// ====================================================================

const DEFAULT_ALLOWLIST = Object.freeze(['imgur.com', 'youtube.com', 'youtu.be', 'giphy.com']);
const ALLOWLIST_CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes
const ALLOWLIST_LOG_PREFIX = '[Allowlist]';

let allowlistCache = null;
let allowlistCacheFetchedAt = 0;

const SQL_MIRROR_DM_SOURCE = 'cloudfunction://messaging/sendMessage';
let cachedClientSqlMirrorFlag = null;

function normalizeBooleanFlag(value, defaultValue = false) {
  if (value === undefined || value === null) {
    return defaultValue;
  }
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'number') {
    return value !== 0;
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (['true', '1', 'yes', 'on'].includes(normalized)) {
      return true;
    }
    if (['false', '0', 'no', 'off'].includes(normalized)) {
      return false;
    }
  }
  return defaultValue;
}

function resolveClientSqlMirrorFlag() {
  const envCandidates = [
    process.env.ENABLE_CLIENT_DM_SQL_DOUBLEWRITE,
    process.env.ENABLE_CLIENT_SQL_DOUBLEWRITE,
    process.env.ENABLE_CLIENT_SQL_MIRROR,
    process.env.ENABLE_SQL_MIRROR_DOUBLEWRITE,
  ];

  for (const candidate of envCandidates) {
    if (candidate !== undefined) {
      return normalizeBooleanFlag(candidate, false);
    }
  }

  try {
    const messagingConfig = functions.config()?.messaging || {};
    const configCandidates = [
      messagingConfig.enable_client_dm_sql_doublewrite,
      messagingConfig.enable_client_sql_doublewrite,
      messagingConfig.enable_client_sql_mirror,
      messagingConfig.enable_sql_mirror_doublewrite,
    ];

    for (const candidate of configCandidates) {
      if (candidate !== undefined) {
        return normalizeBooleanFlag(candidate, false);
      }
    }
  } catch (error) {
    // Ignore when functions config is not available (e.g. local tests)
  }

  return false;
}

function isClientSqlMirrorEnabled({ forceRefresh = false } = {}) {
  if (!forceRefresh && typeof cachedClientSqlMirrorFlag === 'boolean') {
    return cachedClientSqlMirrorFlag;
  }

  cachedClientSqlMirrorFlag = resolveClientSqlMirrorFlag();
  return cachedClientSqlMirrorFlag;
}

function logAllowlistFallback(message, error) {
  if (!error) {
    console.warn(`${ALLOWLIST_LOG_PREFIX} ${message}`);
    return;
  }

  const errorMessage = typeof error.message === 'string' ? error.message : '';
  const missingCredentials = errorMessage.includes('Could not load the default credentials') ||
    errorMessage.includes('environment variable GOOGLE_APPLICATION_CREDENTIALS');

  if (missingCredentials) {
    console.warn(`${ALLOWLIST_LOG_PREFIX} ${message} (missing Google credentials).`);
  } else {
    console.error(`${ALLOWLIST_LOG_PREFIX} ${message}`, error);
  }
}

// ====================================================================
// CONVERSATION HELPERS
// ====================================================================

function normalizeUid(uid) {
  if (typeof uid !== 'string') {
    return null;
  }
  const trimmed = uid.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function generateConversationId(uidA, uidB) {
  const normalizedA = normalizeUid(uidA);
  const normalizedB = normalizeUid(uidB);

  if (!normalizedA || !normalizedB) {
    throw new functions.https.HttpsError('invalid-argument', 'Geçerli kullanıcı kimlikleri gerekli.');
  }

  if (normalizedA === normalizedB) {
    throw new functions.https.HttpsError('invalid-argument', 'Kendinizle sohbet başlatamazsınız.');
  }

  const sorted = [normalizedA, normalizedB].sort((a, b) => a.localeCompare(b));
  return `${sorted[0]}_${sorted[1]}`;
}

function sanitizeParticipantMeta(rawMeta, memberIds) {
  if (!rawMeta || typeof rawMeta !== 'object') {
    return {};
  }

  const allowedKeys = new Set(['displayName', 'username', 'avatar']);
  const sanitized = {};

  memberIds.forEach((memberId) => {
    const meta = rawMeta[memberId];
    if (!meta || typeof meta !== 'object') {
      return;
    }

    const cleaned = {};
    Object.entries(meta).forEach(([key, value]) => {
      if (!allowedKeys.has(key)) {
        return;
      }
      if (typeof value === 'string') {
        cleaned[key] = value.trim();
      }
    });

    if (Object.keys(cleaned).length > 0) {
      sanitized[memberId] = cleaned;
    }
  });

  return sanitized;
}

function buildParticipantMetaUpdates(meta) {
  const updates = {};
  Object.entries(meta).forEach(([uid, fields]) => {
    Object.entries(fields).forEach(([field, value]) => {
      updates[`participantMeta.${uid}.${field}`] = value;
    });
  });
  return updates;
}

function mergeParticipantMeta(existingMeta, updates) {
  const merged = {};

  if (existingMeta && typeof existingMeta === 'object') {
    Object.entries(existingMeta).forEach(([uid, fields]) => {
      if (!fields || typeof fields !== 'object') {
        return;
      }
      merged[uid] = { ...fields };
    });
  }

  if (updates && typeof updates === 'object') {
    Object.entries(updates).forEach(([uid, fields]) => {
      if (!fields || typeof fields !== 'object') {
        return;
      }
      const current = merged[uid] && typeof merged[uid] === 'object' ? { ...merged[uid] } : {};
      Object.entries(fields).forEach(([field, value]) => {
        current[field] = value;
      });
      merged[uid] = current;
    });
  }

  return merged;
}

function sanitizeClientMessageId(value) {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    return null;
  }
  if (!/^[A-Za-z0-9_-]{6,64}$/.test(trimmed)) {
    return null;
  }
  return trimmed;
}

// ====================================================================
// HELPER FUNCTIONS
// ====================================================================

/**
 * Normalizes a URL for validation
 * @param {string} urlString - Raw URL string
 * @returns {URL|null} - Parsed URL object or null if invalid
 */
function normalizeUrl(urlString) {
  try {
    const url = new URL(urlString);
    // Only allow http/https
    if (!['http:', 'https:'].includes(url.protocol)) {
      return null;
    }
    return url;
  } catch (error) {
    return null;
  }
}

/**
 * Extracts domain from URL
 * @param {URL} url - URL object
 * @returns {string} - Domain (hostname)
 */
function extractDomain(url) {
  return url.hostname.toLowerCase();
}

/**
 * Checks if domain is in allowlist
 * @param {string} domain - Domain to check
 * @param {Array<string>} allowlist - Allowed domains
 * @returns {boolean} - True if allowed
 */
function isDomainAllowed(domain, allowlist) {
  return allowlist.some((allowed) => {
    const normalizedAllowed = allowed.toLowerCase();
    // Exact match or subdomain
    return domain === normalizedAllowed || domain.endsWith(`.${normalizedAllowed}`);
  });
}

/**
 * Validates external media URL via HEAD request
 * @param {URL} url - URL object to validate
 * @returns {Promise<{valid: boolean, contentType?: string, contentLength?: number, error?: string}>}
 */
async function validateUrlContent(url) {
  return new Promise((resolve) => {
    const protocol = url.protocol === 'https:' ? https : http;
    
    const options = {
      method: 'HEAD',
      hostname: url.hostname,
      path: url.pathname + url.search,
      timeout: 5000, // 5 second timeout
      headers: {
        'User-Agent': 'CringeBank-Bot/1.0',
      },
    };

    const req = protocol.request(options, (res) => {
      const contentType = res.headers['content-type'] || '';
      const contentLength = parseInt(res.headers['content-length'] || '0', 10);

      // Check if it's media content
      const isMedia = contentType.startsWith('image/') || 
                      contentType.startsWith('video/') ||
                      contentType.startsWith('audio/');

      if (!isMedia) {
        resolve({
          valid: false,
          error: 'Not a media file',
        });
        return;
      }

      // Check size limit (50MB)
      if (contentLength > 50 * 1024 * 1024) {
        resolve({
          valid: false,
          error: 'File too large',
        });
        return;
      }

      resolve({
        valid: true,
        contentType,
        contentLength,
      });
    });

    req.on('error', (error) => {
      resolve({
        valid: false,
        error: error.message,
      });
    });

    req.on('timeout', () => {
      req.destroy();
      resolve({
        valid: false,
        error: 'Request timeout',
      });
    });

    req.end();
  });
}

/**
 * Loads allowlist from Firestore config
 * @returns {Promise<Array<string>>} - Allowed domains
 */
async function loadAllowlist({ forceRefresh = false } = {}) {
  const now = Date.now();

  if (!forceRefresh && Array.isArray(allowlistCache) && now - allowlistCacheFetchedAt < ALLOWLIST_CACHE_TTL_MS) {
    return [...allowlistCache];
  }

  try {
    const doc = await admin.firestore().collection('config').doc('allowedMediaHosts').get();
    if (!doc.exists) {
      logAllowlistFallback('Document not found, using defaults');
      allowlistCache = [...DEFAULT_ALLOWLIST];
    } else {
      const data = doc.data() || {};
      const rawHosts = Array.isArray(data.hosts) ? data.hosts : [];
      const sanitizedHosts = rawHosts
        .filter((host) => typeof host === 'string')
        .map((host) => host.trim().toLowerCase())
        .filter(Boolean);

      if (sanitizedHosts.length === 0) {
        logAllowlistFallback('Document has no valid hosts, using defaults');
        allowlistCache = [...DEFAULT_ALLOWLIST];
      } else {
        allowlistCache = [...new Set(sanitizedHosts)];
      }
    }
  } catch (error) {
    logAllowlistFallback('Error loading allowlist, using defaults', error);
    allowlistCache = [...DEFAULT_ALLOWLIST];
  }

  allowlistCacheFetchedAt = now;
  return [...allowlistCache];
}

/**
 * Validates external media object
 * @param {object} mediaExternal - Media external object
 * @param {Array<string>} allowlist - Allowed domains
 * @returns {Promise<{valid: boolean, error?: string}>}
 */
async function validateExternalMedia(mediaExternal, allowlist) {
  if (!mediaExternal || typeof mediaExternal !== 'object') {
    return { valid: false, error: 'Invalid mediaExternal object' };
  }

  const { url: urlString, type } = mediaExternal;

  if (!urlString || typeof urlString !== 'string') {
    return { valid: false, error: 'Missing or invalid URL' };
  }

  if (!type || !['image', 'video', 'audio'].includes(type)) {
    return { valid: false, error: 'Invalid media type' };
  }

  // Normalize URL
  const url = normalizeUrl(urlString);
  if (!url) {
    return { valid: false, error: 'Invalid URL format' };
  }

  // Check domain
  const domain = extractDomain(url);
  if (!isDomainAllowed(domain, allowlist)) {
    return { valid: false, error: `Domain not allowed: ${domain}` };
  }

  // Validate content via HEAD request
  const validation = await validateUrlContent(url);
  if (!validation.valid) {
    return { valid: false, error: validation.error };
  }

  return { valid: true };
}

function buildDmSqlMirrorEnvelope({
  conversationId,
  messageId,
  clientMessageId,
  senderId,
  recipientId,
  text,
  media,
  mediaExternal,
  participantMeta,
  timestampIso,
}) {
  const iso = timestampIso || new Date().toISOString();
  const normalizedMedia = Array.isArray(media)
    ? media
        .map((item) => (typeof item === 'string' ? item.trim() : ''))
        .filter((item) => item.length > 0)
    : [];

  const document = {
    senderId,
    conversationId,
    clientMessageId,
    createdAt: iso,
    updatedAt: iso,
  };

  if (text && typeof text === 'string' && text.trim().length > 0) {
    document.text = text.trim();
  }

  if (normalizedMedia.length > 0) {
    document.media = normalizedMedia;
  }

  if (mediaExternal && typeof mediaExternal === 'object') {
    document.mediaExternal = mediaExternal;
  }

  const attachments = normalizedMedia.map((path) => ({ path }));
  const eventId = `dm.message.create:${conversationId}:${messageId}:${Date.now()}:${Math.random()
    .toString(36)
    .slice(2, 10)}`;

  const participantMetaPayload = participantMeta && typeof participantMeta === 'object' ? participantMeta : null;

  return {
    id: eventId,
    type: 'dm.message.create',
    specversion: '1.0',
    source: SQL_MIRROR_DM_SOURCE,
    time: iso,
    data: {
      operation: 'create',
      conversationId,
      messageId,
      clientMessageId,
      senderId,
      recipientId: recipientId || null,
      timestamp: iso,
      participantMeta: participantMetaPayload,
      document,
      previousDocument: null,
      attachments,
      source: SQL_MIRROR_DM_SOURCE,
    },
  };
}

// ====================================================================
// CLOUD FUNCTIONS
// ====================================================================

/**
 * Create Conversation Function
 * Ensures a two-person conversation document exists and updates metadata
 */
exports.createConversation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Giriş yapmalısınız.');
  }

  const userId = context.auth.uid;
  const otherUserId = normalizeUid(data?.otherUserId);

  if (!otherUserId) {
    throw new functions.https.HttpsError('invalid-argument', 'Geçerli bir hedef kullanıcı ID gerekli.');
  }

  let conversationId;
  try {
    conversationId = generateConversationId(userId, otherUserId);
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('invalid-argument', 'Konuşma oluşturulamadı.');
  }

  const db = admin.firestore();
  const conversationRef = db.collection('conversations').doc(conversationId);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const members = [userId, otherUserId];
  const sanitizedMeta = sanitizeParticipantMeta(data?.participantMeta, members);

  let created = false;

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(conversationRef);

    if (!snapshot.exists) {
      const readPointers = members.reduce((acc, uid) => {
        acc[uid] = null;
        return acc;
      }, {});

      transaction.set(conversationRef, {
        members,
        memberCount: members.length,
        isGroup: false,
        createdAt: now,
        updatedAt: now,
        lastMessageAt: null,
        lastMessageText: '',
        lastSenderId: null,
        lastMessageId: null,
        readPointers,
        participantMeta: sanitizedMeta,
      });

      created = true;
      return;
    }

    const existing = snapshot.data() || {};
    const existingMembers = Array.isArray(existing.members) ? existing.members : [];
    if (!existingMembers.includes(userId) || !existingMembers.includes(otherUserId)) {
      throw new functions.https.HttpsError('permission-denied', 'Bu konuşmaya erişim yetkiniz yok.');
    }

    const updateData = {
      updatedAt: now,
    };

    if (Object.keys(sanitizedMeta).length > 0) {
      Object.assign(updateData, buildParticipantMetaUpdates(sanitizedMeta));
    }

    transaction.update(conversationRef, updateData);
  });

  return {
    conversationId,
    created,
  };
});

/**
 * Send Message Function
 * Validates message, checks rate limits, and creates message document
 */
exports.sendMessage = functions.https.onCall(async (data, context) => {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Giriş yapmalısınız.');
  }

  const userId = context.auth.uid;
  const { conversationId, text, media, mediaExternal } = data;
  const clientMessageId = sanitizeClientMessageId(data?.clientMessageId);

  if (data?.clientMessageId && !clientMessageId) {
    throw new functions.https.HttpsError('invalid-argument', 'Geçersiz clientMessageId.');
  }

  // Validate input
  if (!conversationId) {
    throw new functions.https.HttpsError('invalid-argument', 'Conversation ID gerekli.');
  }

  // Content check
  if (!text && (!media || media.length === 0) && !mediaExternal) {
    throw new functions.https.HttpsError('invalid-argument', 'Mesaj içeriği boş olamaz.');
  }

  const db = admin.firestore();

  try {
    // Check conversation membership
    const conversationRef = db.collection('conversations').doc(conversationId);
    const conversationDoc = await conversationRef.get();

    if (!conversationDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Conversation bulunamadı.');
    }

    const conversationData = conversationDoc.data();
    const members = conversationData.members || [];

    if (!members.includes(userId)) {
      throw new functions.https.HttpsError('permission-denied', 'Bu conversation\'a üye değilsiniz.');
    }

  const participantMetaUpdates = sanitizeParticipantMeta(data?.participantMeta, members);
  const mergedParticipantMeta = mergeParticipantMeta(conversationData.participantMeta, participantMetaUpdates);

    // Check if blocked
    const otherUserId = members.find((m) => m !== userId);
    const [blockedByMe, blockedByThem] = await Promise.all([
      db.collection('blocks').doc(userId).collection('targets').doc(otherUserId).get(),
      db.collection('blocks').doc(otherUserId).collection('targets').doc(userId).get(),
    ]);

    if (blockedByMe.exists || blockedByThem.exists) {
      throw new functions.https.HttpsError('permission-denied', 'Bu kullanıcıyla mesajlaşamazsınız.');
    }

    // Validate external media if present
    let validatedMediaExternal = null;
    if (mediaExternal) {
      const allowlist = await loadAllowlist();
      const validation = await validateExternalMedia(mediaExternal, allowlist);

      if (!validation.valid) {
        throw new functions.https.HttpsError('invalid-argument', `Harici medya geçersiz: ${validation.error}`);
      }

      // Set safe flag and origin domain
      const url = normalizeUrl(mediaExternal.url);
      validatedMediaExternal = {
        ...mediaExternal,
        safe: true,
        originDomain: extractDomain(url),
      };
    }

  // Create message
    const messagesCollection = db.collection('conversations').doc(conversationId).collection('messages');
    const messageRef = clientMessageId ? messagesCollection.doc(clientMessageId) : messagesCollection.doc();

    if (clientMessageId) {
      const existingMessage = await messageRef.get();
      if (existingMessage.exists) {
        throw new functions.https.HttpsError('already-exists', 'Mesaj zaten mevcut.');
      }
    }
    const now = admin.firestore.FieldValue.serverTimestamp();
    const editAllowedUntil = admin.firestore.Timestamp.fromMillis(Date.now() + 15 * 60 * 1000); // 15 minutes
    const eventTimestampIso = new Date().toISOString();
    const normalizedMedia = Array.isArray(media)
      ? media
          .map((item) => (typeof item === 'string' ? item.trim() : ''))
          .filter((item) => item.length > 0)
      : [];

    const messageData = {
      senderId: userId,
      createdAt: now,
      updatedAt: now,
      editAllowedUntil,
      rateKey: 'ok', // Rate limiting passed
      deletedFor: {},
    };

    if (text) messageData.text = text;
    if (normalizedMedia.length > 0) messageData.media = normalizedMedia;
    if (validatedMediaExternal) messageData.mediaExternal = validatedMediaExternal;

    await messageRef.set(messageData);

    // Update conversation
    const previewText = text || (validatedMediaExternal ? `[${(mediaExternal.type || 'Medya').toString().toUpperCase()}]` : '[Medya]');
    const conversationUpdate = {
      updatedAt: now,
      lastMessageAt: now,
      lastMessageText: previewText,
      lastSenderId: userId,
      lastMessageId: messageRef.id,
      [`readPointers.${userId}`]: messageRef.id,
    };

    if (Object.keys(participantMetaUpdates).length > 0) {
      Object.assign(conversationUpdate, buildParticipantMetaUpdates(participantMetaUpdates));
    }

    await conversationRef.update(conversationUpdate);

    const shouldMirrorSql = isClientSqlMirrorEnabled();
    const effectiveClientMessageId = clientMessageId || messageRef.id;
    const sqlMirrorEnvelope = shouldMirrorSql
      ? buildDmSqlMirrorEnvelope({
          conversationId,
          messageId: messageRef.id,
          clientMessageId: effectiveClientMessageId,
          senderId: userId,
          recipientId: otherUserId,
          text,
          media: normalizedMedia,
          mediaExternal: validatedMediaExternal,
          participantMeta: mergedParticipantMeta,
          timestampIso: eventTimestampIso,
        })
      : null;

    return {
      success: true,
      messageId: messageRef.id,
      clientMessageId: effectiveClientMessageId,
      shouldMirrorSql,
      sqlMirrorEnvelope,
      timestamp: eventTimestampIso,
      createdAt: eventTimestampIso,
      updatedAt: eventTimestampIso,
      previousDocument: null,
    };
  } catch (error) {
    console.error('Error sending message:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Mesaj gönderme hatası.');
  }
});

/**
 * Edit Message Function
 * Validates edit window and updates message
 */
exports.editMessage = functions.https.onCall(async (data, context) => {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Giriş yapmalısınız.');
  }

  const userId = context.auth.uid;
  const { conversationId, messageId, text, mediaExternal } = data;

  // Validate input
  if (!conversationId || !messageId) {
    throw new functions.https.HttpsError('invalid-argument', 'Conversation ID ve Message ID gerekli.');
  }

  const db = admin.firestore();

  try {
    // Get message
    const messageRef = db.collection('conversations').doc(conversationId).collection('messages').doc(messageId);
    const messageDoc = await messageRef.get();

    if (!messageDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Mesaj bulunamadı.');
    }

    const messageData = messageDoc.data();

    // Check ownership
    if (messageData.senderId !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'Sadece kendi mesajınızı düzenleyebilirsiniz.');
    }

    // Check tombstone
    if (messageData.tombstone?.active) {
      throw new functions.https.HttpsError('permission-denied', 'Silinmiş mesaj düzenlenemez.');
    }

    // Check edit window
    const now = Date.now();
    const editAllowedUntil = messageData.editAllowedUntil?.toMillis() || 0;

    if (now > editAllowedUntil) {
      throw new functions.https.HttpsError('permission-denied', 'Düzenleme süresi dolmuş (15 dakika).');
    }

    // Validate external media if changed
    let validatedMediaExternal = messageData.mediaExternal || null;
    if (mediaExternal !== undefined) {
      if (mediaExternal === null) {
        validatedMediaExternal = null;
      } else {
        const allowlist = await loadAllowlist();
        const validation = await validateExternalMedia(mediaExternal, allowlist);

        if (!validation.valid) {
          throw new functions.https.HttpsError('invalid-argument', `Harici medya geçersiz: ${validation.error}`);
        }

        const url = normalizeUrl(mediaExternal.url);
        validatedMediaExternal = {
          ...mediaExternal,
          safe: true,
          originDomain: extractDomain(url),
        };
      }
    }

    // Update message
    const updateData = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'edited.at': admin.firestore.FieldValue.serverTimestamp(),
      'edited.by': userId,
    };

    if (text !== undefined) updateData.text = text;
    if (mediaExternal !== undefined) {
      updateData.mediaExternal = validatedMediaExternal;
    }

    await messageRef.update(updateData);

    return {
      success: true,
    };
  } catch (error) {
    console.error('Error editing message:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Mesaj düzenleme hatası.');
  }
});

/**
 * Delete Message Function
 * Sets tombstone and optionally deletes storage media
 */
exports.deleteMessage = functions.https.onCall(async (data, context) => {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Giriş yapmalısınız.');
  }

  const userId = context.auth.uid;
  const { conversationId, messageId, deleteMode } = data;

  // Validate input
  if (!conversationId || !messageId) {
    throw new functions.https.HttpsError('invalid-argument', 'Conversation ID ve Message ID gerekli.');
  }

  if (!['only-me', 'for-both'].includes(deleteMode)) {
    throw new functions.https.HttpsError('invalid-argument', 'Geçersiz silme modu.');
  }

  const db = admin.firestore();

  try {
    // Get message
    const messageRef = db.collection('conversations').doc(conversationId).collection('messages').doc(messageId);
    const messageDoc = await messageRef.get();

    if (!messageDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Mesaj bulunamadı.');
    }

    const messageData = messageDoc.data();

    // Check ownership for "for-both" mode
    if (deleteMode === 'for-both' && messageData.senderId !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'Sadece kendi mesajınızı herkes için silebilirsiniz.');
    }

    // Update based on mode
    if (deleteMode === 'only-me') {
      // Soft delete
      await messageRef.update({
        [`deletedFor.${userId}`]: true,
      });
    } else {
      // Hard delete (tombstone)
      await messageRef.update({
        'tombstone.active': true,
        'tombstone.at': admin.firestore.FieldValue.serverTimestamp(),
        'tombstone.by': userId,
      });

      // Delete storage media if present
      if (messageData.media && messageData.media.length > 0) {
        const bucket = admin.storage().bucket();
        const deletePromises = messageData.media.map((path) => {
          return bucket.file(path).delete().catch((err) => {
            console.warn(`Failed to delete media: ${path}`, err);
          });
        });
        await Promise.all(deletePromises);
      }
    }

    return {
      success: true,
    };
  } catch (error) {
    console.error('Error deleting message:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Mesaj silme hatası.');
  }
});

/**
 * Set Read Pointer Function
 * Updates user's read pointer in conversation
 */
exports.setReadPointer = functions.https.onCall(async (data, context) => {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Giriş yapmalısınız.');
  }

  const userId = context.auth.uid;
  const { conversationId, messageId } = data;

  // Validate input
  if (!conversationId || !messageId) {
    throw new functions.https.HttpsError('invalid-argument', 'Conversation ID ve Message ID gerekli.');
  }

  const db = admin.firestore();

  try {
    // Check conversation membership
    const conversationRef = db.collection('conversations').doc(conversationId);
    const conversationDoc = await conversationRef.get();

    if (!conversationDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Conversation bulunamadı.');
    }

    const conversationData = conversationDoc.data();
    const members = conversationData.members || [];

    if (!members.includes(userId)) {
      throw new functions.https.HttpsError('permission-denied', 'Bu conversation\'a üye değilsiniz.');
    }

    // Update read pointer
    await conversationRef.update({
      [`readPointers.${userId}`]: messageId,
    });

    return {
      success: true,
    };
  } catch (error) {
    console.error('Error setting read pointer:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Read pointer güncelleme hatası.');
  }
});
