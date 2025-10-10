#!/usr/bin/env node
'use strict';

/**
 * dm_follow_consistency.js
 * ------------------------
 * Compares SQL mirror rows (DmConversation, DmMessage, FollowEdge) with the
 * source Firestore documents to highlight missing or divergent records.
 *
 * Usage examples:
 *   node scripts/dm_follow_consistency.js --check=conversations --limit=20
 *   node scripts/dm_follow_consistency.js --conversation=alice_bob --check=messages
 *   node scripts/dm_follow_consistency.js --check=follow --follower=user_alice --limit=100 --output=json
 *
 * Required environment:
 *   - GOOGLE_APPLICATION_CREDENTIALS (or equivalent firebase-admin credentials)
 *   - SQLSERVER_HOST, SQLSERVER_USER, SQLSERVER_PASS, SQLSERVER_DB (and optional SQLSERVER_PORT, ...)
 */

const admin = require('firebase-admin');
const mssql = require('mssql');
const path = require('path');
const { serializeValue } = require('../functions/realtime_mirror/serializer');

const argv = process.argv.slice(2);

function hasFlag(flag) {
  return argv.includes(flag);
}

function getOption(name, fallback = null) {
  const prefix = `--${name}=`;
  const direct = argv.find((arg) => arg.startsWith(prefix));
  if (direct) {
    return direct.slice(prefix.length);
  }
  return fallback;
}

function parseCheckSet() {
  const raw = getOption('check', process.env.CONSISTENCY_CHECK || 'conversations,messages,follow');
  return new Set(
    raw
      .split(',')
      .map((token) => token.trim().toLowerCase())
      .filter(Boolean),
  );
}

const defaultOptions = (() => {
  const parsedLimit = (() => {
    const raw = getOption('limit', process.env.CONSISTENCY_LIMIT || '50');
    const parsed = Number.parseInt(raw, 10);
    if (Number.isNaN(parsed) || parsed <= 0) {
      return 50;
    }
    return Math.min(parsed, 500);
  })();

  const outputMode = (getOption('output', process.env.CONSISTENCY_OUTPUT || 'table') || 'table')
    .toString()
    .trim()
    .toLowerCase();

  return {
    checks: parseCheckSet(),
    limit: parsedLimit,
    conversationFilter: getOption('conversation', process.env.CONSISTENCY_CONVERSATION_ID || null),
    followerFilter: getOption('follower', process.env.CONSISTENCY_FOLLOW_USER || null),
    output: outputMode === 'json' ? 'json' : 'table',
    verbose: hasFlag('--verbose'),
    setExitCode: true,
    silent: false,
  };
})();

function info(message, payload = {}) {
  console.info(`[consistency] ${message}`, payload);
}

function warn(message, payload = {}) {
  console.warn(`[consistency] ${message}`, payload);
}

function error(message, payload = {}) {
  console.error(`[consistency] ${message}`, payload);
}

function ensureFirebaseInitialized() {
  if (admin.apps.length === 0) {
    admin.initializeApp();
    info('Initialized firebase-admin app');
  }
  return admin.firestore();
}

const sqlConfig = {
  server: process.env.SQLSERVER_HOST,
  user: process.env.SQLSERVER_USER,
  password: process.env.SQLSERVER_PASS,
  database: process.env.SQLSERVER_DB,
  port: process.env.SQLSERVER_PORT ? Number(process.env.SQLSERVER_PORT) : undefined,
  pool: {
    max: Number.parseInt(process.env.SQLSERVER_POOL_MAX || '10', 10),
    min: Number.parseInt(process.env.SQLSERVER_POOL_MIN || '0', 10),
    idleTimeoutMillis: Number.parseInt(process.env.SQLSERVER_POOL_IDLE || '30000', 10),
  },
  options: {
    encrypt: process.env.SQLSERVER_ENCRYPT === 'false' ? false : true,
    trustServerCertificate: process.env.SQLSERVER_TRUST_CERT === 'true',
  },
};

function ensureSqlConfigValid() {
  const missing = [];
  if (!sqlConfig.server) missing.push('SQLSERVER_HOST');
  if (!sqlConfig.user) missing.push('SQLSERVER_USER');
  if (!sqlConfig.password) missing.push('SQLSERVER_PASS');
  if (!sqlConfig.database) missing.push('SQLSERVER_DB');
  if (missing.length > 0) {
    throw new Error(`Missing SQL configuration variables: ${missing.join(', ')}`);
  }
}

let poolPromise = null;
async function getSqlPool() {
  if (!poolPromise) {
    ensureSqlConfigValid();
    poolPromise = (async () => {
      const pool = new mssql.ConnectionPool(sqlConfig);
      pool.on('error', (err) => error('SQL pool error', { err }));
      await pool.connect();
      return pool;
    })();
  }
  return poolPromise;
}

function normalizeString(value) {
  if (value === null || value === undefined) return null;
  return String(value).trim();
}

function normalizeBoolean(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const lowered = value.trim().toLowerCase();
    if (['true', '1', 'yes'].includes(lowered)) return true;
    if (['false', '0', 'no'].includes(lowered)) return false;
  }
  return null;
}

function normalizeNumber(value) {
  if (value === null || value === undefined) return null;
  const parsed = Number(value);
  if (Number.isNaN(parsed)) return null;
  return parsed;
}

function normalizeTimestamp(value) {
  if (value === null || value === undefined) return null;
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'string') return new Date(value).toISOString();
  if (typeof value === 'number') return new Date(value).toISOString();
  if (typeof value === 'object' && typeof value.toDate === 'function') {
    return value.toDate().toISOString();
  }
  return null;
}

function compareField(diffs, field, sqlValue, firestoreValue, normalizer = (val) => val) {
  const left = normalizer(sqlValue);
  const right = normalizer(firestoreValue);
  if (left === null && right === null) {
    return;
  }
  if (left === right) {
    return;
  }
  diffs.push({ field, sql: left, firestore: right });
}

function extractFirestoreData(snapshot) {
  if (!snapshot || !snapshot.exists) {
    return null;
  }
  const raw = snapshot.data();
  if (!raw) {
    return null;
  }
  return serializeValue(raw);
}

async function checkConversations(pool, firestore, { limit, conversationFilter, verbose } = {}) {
  const result = {
    checked: 0,
    missingFirestore: [],
    mismatches: [],
  };

  const request = pool.request();
  request.input('limit', mssql.Int, limit);

  let sql = `
    SELECT TOP (@limit)
      c.ConversationId,
      c.FirestoreId AS ConversationFirestoreId,
      c.Type,
      c.IsGroup,
      c.MemberCount,
      c.LastMessageFirestoreId,
      c.LastMessageSenderId,
      c.LastMessagePreview,
      c.LastMessageTimestamp,
      c.CreatedAt,
      c.UpdatedAt
    FROM dbo.DmConversation c
  `;

  if (conversationFilter) {
    sql += ' WHERE c.FirestoreId = @conversationId';
    request.input('conversationId', mssql.NVarChar(256), conversationFilter);
  }

  sql += ' ORDER BY c.UpdatedAt DESC;';

  const rows = await request.query(sql).then((res) => res.recordset || []);
  result.checked = rows.length;

  for (const row of rows) {
    const convoId = normalizeString(row.ConversationFirestoreId);
    if (!convoId) {
      continue;
    }

    const snapshot = await firestore.collection('conversations').doc(convoId).get();
    const data = extractFirestoreData(snapshot);

    if (!data) {
      result.missingFirestore.push({ conversationId: convoId });
      continue;
    }

    const diffs = [];
    compareField(diffs, 'type', row.Type, data.type, (val) => normalizeString(val)?.toLowerCase());
    compareField(diffs, 'isGroup', row.IsGroup, data.isGroup, normalizeBoolean);
    const firestoreMemberCount = data.memberCount ?? (Array.isArray(data.members) ? data.members.length : null);
    compareField(diffs, 'memberCount', row.MemberCount, firestoreMemberCount, normalizeNumber);
    compareField(diffs, 'lastMessageId', row.LastMessageFirestoreId, data.lastMessageId, normalizeString);
    compareField(diffs, 'lastMessageSenderId', row.LastMessageSenderId, data.lastSenderId, normalizeString);
    compareField(diffs, 'lastMessageText', row.LastMessagePreview, data.lastMessageText, normalizeString);
    compareField(diffs, 'lastMessageTimestamp', row.LastMessageTimestamp, data.lastMessageAt, normalizeTimestamp);
    compareField(diffs, 'updatedAt', row.UpdatedAt, data.updatedAt, normalizeTimestamp);

    if (diffs.length > 0) {
      result.mismatches.push({ conversationId: convoId, diffs });
      if (verbose) {
        warn('Conversation mismatch detected', { conversationId: convoId, diffs });
      }
    }
  }

  return result;
}

async function checkMessages(pool, firestore, { limit, conversationFilter, verbose } = {}) {
  const result = {
    checked: 0,
    missingFirestore: [],
    mismatches: [],
  };

  const request = pool.request();
  request.input('limit', mssql.Int, limit);

  let sql = `
    SELECT TOP (@limit)
      m.MessageId,
      m.FirestoreId AS MessageFirestoreId,
      c.FirestoreId AS ConversationFirestoreId,
      m.AuthorUserId,
      m.ClientMessageId,
      m.BodyText,
      m.CreatedAt,
      m.UpdatedAt,
      m.EditedAt,
      m.EditedBy,
      m.DeletedAt,
      m.DeletedBy,
      m.Source
    FROM dbo.DmMessage m
    INNER JOIN dbo.DmConversation c ON c.ConversationId = m.ConversationId
  `;

  if (conversationFilter) {
    sql += ' WHERE c.FirestoreId = @conversationId';
    request.input('conversationId', mssql.NVarChar(256), conversationFilter);
  }

  sql += ' ORDER BY m.UpdatedAt DESC;';

  const rows = await request.query(sql).then((res) => res.recordset || []);
  result.checked = rows.length;

  for (const row of rows) {
    const convoId = normalizeString(row.ConversationFirestoreId);
    const messageId = normalizeString(row.MessageFirestoreId);
    if (!convoId || !messageId) {
      continue;
    }

    const snapshot = await firestore
      .collection('conversations')
      .doc(convoId)
      .collection('messages')
      .doc(messageId)
      .get();

    const data = extractFirestoreData(snapshot);
    if (!data) {
      result.missingFirestore.push({ conversationId: convoId, messageId });
      continue;
    }

    const diffs = [];
    compareField(diffs, 'senderId', row.AuthorUserId, data.senderId, normalizeString);
    compareField(diffs, 'clientMessageId', row.ClientMessageId, data.clientMessageId, normalizeString);
    compareField(diffs, 'text', row.BodyText, data.text, normalizeString);
    compareField(diffs, 'createdAt', row.CreatedAt, data.createdAt, normalizeTimestamp);
    compareField(diffs, 'updatedAt', row.UpdatedAt, data.updatedAt ?? data.lastUpdatedAt, normalizeTimestamp);
    compareField(diffs, 'editedAt', row.EditedAt, data?.edited?.at, normalizeTimestamp);
    compareField(diffs, 'editedBy', row.EditedBy, data?.edited?.by, normalizeString);
    compareField(diffs, 'deletedAt', row.DeletedAt, data?.tombstone?.at, normalizeTimestamp);
    compareField(diffs, 'deletedBy', row.DeletedBy, data?.tombstone?.by, normalizeString);
    compareField(diffs, 'source', row.Source, data.source, normalizeString);

    if (diffs.length > 0) {
      result.mismatches.push({ conversationId: convoId, messageId, diffs });
      if (verbose) {
        warn('Message mismatch detected', { conversationId: convoId, messageId, diffs });
      }
    }
  }

  return result;
}

async function checkFollow(pool, firestore, { limit, followerFilter, verbose } = {}) {
  const result = {
    checked: 0,
    missingFirestore: [],
    mismatches: [],
  };

  const request = pool.request();
  request.input('limit', mssql.Int, limit);

  let sql = `
    SELECT TOP (@limit)
      f.FollowerUserId,
      f.TargetUserId,
      f.State,
      f.Source,
      f.CreatedAt,
      f.UpdatedAt
    FROM dbo.FollowEdge f
  `;

  if (followerFilter) {
    sql += ' WHERE f.FollowerUserId = @follower';
    request.input('follower', mssql.NVarChar(256), followerFilter);
  }

  sql += ' ORDER BY f.UpdatedAt DESC;';

  const rows = await request.query(sql).then((res) => res.recordset || []);
  result.checked = rows.length;

  for (const row of rows) {
    const follower = normalizeString(row.FollowerUserId);
    const target = normalizeString(row.TargetUserId);
    if (!follower || !target) {
      continue;
    }

    const snapshot = await firestore
      .collection('follows')
      .doc(follower)
      .collection('targets')
      .doc(target)
      .get();

    const data = extractFirestoreData(snapshot);
    if (!data) {
      result.missingFirestore.push({ follower, target });
      continue;
    }

    const diffs = [];
    compareField(diffs, 'status/state', row.State, data.status, (value) => normalizeString(value)?.toUpperCase());
    compareField(diffs, 'source', row.Source, data.source, (value) => normalizeString(value)?.toLowerCase());
    compareField(diffs, 'createdAt', row.CreatedAt, data.createdAt, normalizeTimestamp);
    compareField(diffs, 'updatedAt', row.UpdatedAt, data.updatedAt, normalizeTimestamp);

    if (diffs.length > 0) {
      result.mismatches.push({ follower, target, diffs });
      if (verbose) {
        warn('Follow edge mismatch detected', { follower, target, diffs });
      }
    }
  }

  return result;
}

function renderSummary(summary, { output }) {
  if (output === 'json') {
    console.log(JSON.stringify(summary, null, 2));
    return;
  }

  console.log('\n[consistency] Summary');
  console.table([
    {
      check: 'conversations',
      checked: summary.conversations?.checked ?? 0,
      missing: summary.conversations?.missingFirestore?.length ?? 0,
      mismatches: summary.conversations?.mismatches?.length ?? 0,
    },
    {
      check: 'messages',
      checked: summary.messages?.checked ?? 0,
      missing: summary.messages?.missingFirestore?.length ?? 0,
      mismatches: summary.messages?.mismatches?.length ?? 0,
    },
    {
      check: 'follow',
      checked: summary.follow?.checked ?? 0,
      missing: summary.follow?.missingFirestore?.length ?? 0,
      mismatches: summary.follow?.mismatches?.length ?? 0,
    },
  ]);

  if ((summary.conversations?.missingFirestore?.length ?? 0) > 0) {
    console.log('\nMissing conversations (first 10):');
    console.table(summary.conversations.missingFirestore.slice(0, 10));
  }
  if ((summary.conversations?.mismatches?.length ?? 0) > 0) {
    console.log('\nConversation mismatches (first 5):');
    console.table(summary.conversations.mismatches.slice(0, 5));
  }

  if ((summary.messages?.missingFirestore?.length ?? 0) > 0) {
    console.log('\nMissing messages (first 10):');
    console.table(summary.messages.missingFirestore.slice(0, 10));
  }
  if ((summary.messages?.mismatches?.length ?? 0) > 0) {
    console.log('\nMessage mismatches (first 5):');
    console.table(summary.messages.mismatches.slice(0, 5));
  }

  if ((summary.follow?.missingFirestore?.length ?? 0) > 0) {
    console.log('\nMissing follow edges (first 10):');
    console.table(summary.follow.missingFirestore.slice(0, 10));
  }
  if ((summary.follow?.mismatches?.length ?? 0) > 0) {
    console.log('\nFollow edge mismatches (first 5):');
    console.table(summary.follow.mismatches.slice(0, 5));
  }
}

async function main(overrides = {}) {
  const options = {
    ...defaultOptions,
    ...overrides,
    checks: overrides.checks ? new Set(overrides.checks) : new Set(defaultOptions.checks),
  };

  const outputMode = options.output === 'json' ? 'json' : 'table';
  const shouldSetExitCode = overrides.setExitCode ?? defaultOptions.setExitCode;
  const renderFn = overrides.renderSummary ?? renderSummary;

  info('Starting consistency check', {
    limit: options.limit,
    conversationFilter: options.conversationFilter,
    followerFilter: options.followerFilter,
    checks: Array.from(options.checks.values()),
    output: outputMode,
    verbose: options.verbose,
    silent: options.silent,
  });

  let pool;
  let shouldClosePool = false;

  try {
    const firestore = overrides.firestore || ensureFirebaseInitialized();
    pool = overrides.pool;
    if (!pool) {
      pool = await getSqlPool();
      shouldClosePool = true;
    }

    const summary = {};
    if (options.checks.has('conversations')) {
      summary.conversations = await checkConversations(pool, firestore, {
        limit: options.limit,
        conversationFilter: options.conversationFilter,
        verbose: options.verbose,
      });
    }
    if (options.checks.has('messages')) {
      summary.messages = await checkMessages(pool, firestore, {
        limit: options.limit,
        conversationFilter: options.conversationFilter,
        verbose: options.verbose,
      });
    }
    if (options.checks.has('follow')) {
      summary.follow = await checkFollow(pool, firestore, {
        limit: options.limit,
        followerFilter: options.followerFilter,
        verbose: options.verbose,
      });
    }

    if (!options.silent && typeof renderFn === 'function') {
      renderFn(summary, { output: outputMode });
    }

    const hasIssues = [summary.conversations, summary.messages, summary.follow]
      .filter(Boolean)
      .some((section) => (section.missingFirestore?.length ?? 0) > 0 || (section.mismatches?.length ?? 0) > 0);

    if (hasIssues && shouldSetExitCode) {
      process.exitCode = 2;
    }

    return summary;
  } catch (err) {
    error('Consistency check failed', { error: err.message, stack: err.stack });
    if (shouldSetExitCode) {
      process.exitCode = 1;
    }
    throw err;
  } finally {
    if (shouldClosePool && pool) {
      await pool.close().catch((err) => error('Error closing SQL pool', { err }));
    }
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  main,
  checkConversations,
  checkMessages,
  checkFollow,
  renderSummary,
  defaultOptions,
  ensureFirebaseInitialized,
  getSqlPool,
};
