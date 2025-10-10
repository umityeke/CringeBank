#!/usr/bin/env node
'use strict';

/**
 * Backfill Firestore follow edges into SQL dbo.FollowEdge.
 *
 * Usage examples:
 *   node scripts/sql/backfill_follow_edges.js --dry-run --limit=50
 *   node scripts/sql/backfill_follow_edges.js --batch-size=200
 *   node scripts/sql/backfill_follow_edges.js --follower=user_alice --strict
 */

const admin = require('firebase-admin');
const mssql = require('mssql');

const argv = process.argv.slice(2);

const parseFlag = (flag) => argv.some((token) => token === flag);
const parseOption = (name, defaultValue) => {
  const prefix = `--${name}=`;
  const match = argv.find((token) => token.startsWith(prefix));
  if (!match) {
    return defaultValue;
  }
  return match.slice(prefix.length);
};

const isDryRun = parseFlag('--dry-run') || process.env.BACKFILL_DRY_RUN === 'true';
const followerFilter = parseOption('follower', process.env.BACKFILL_FOLLOWER || null);
const limitEdgesRaw = parseOption('limit', process.env.BACKFILL_LIMIT || null);
const batchSizeRaw = parseOption('batch-size', process.env.BACKFILL_BATCH_SIZE || '200');
const stopAtFirstError = parseFlag('--strict') || process.env.BACKFILL_STRICT === 'true';

const batchSize = Number.parseInt(batchSizeRaw, 10);
if (Number.isNaN(batchSize) || batchSize <= 0 || batchSize > 1000) {
  console.error('Invalid batch-size; must be between 1 and 1000.');
  process.exitCode = 1;
  process.exit(1);
}

const limitEdges = limitEdgesRaw != null ? Number.parseInt(limitEdgesRaw, 10) : null;
if (limitEdgesRaw != null && (Number.isNaN(limitEdges) || limitEdges <= 0)) {
  console.error('Invalid limit; must be a positive integer.');
  process.exitCode = 1;
  process.exit(1);
}

function ensureFirebaseInitialized() {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
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
    console.error(`Missing SQL configuration variables: ${missing.join(', ')}`);
    process.exitCode = 1;
    process.exit(1);
  }
}

let sqlPoolPromise;

async function getSqlPool() {
  if (sqlPoolPromise) {
    return sqlPoolPromise;
  }
  ensureSqlConfigValid();
  sqlPoolPromise = (async () => {
    const pool = new mssql.ConnectionPool(sqlConfig);
    pool.on('error', (error) => {
      console.error('SQL pool error:', error);
    });
    await pool.connect();
    return pool;
  })();
  return sqlPoolPromise;
}

function normalizeStatus(status) {
  if (!status) {
    return 'ACTIVE';
  }
  const normalized = status.toString().trim().toUpperCase();
  const allowed = new Set(['ACTIVE', 'PENDING', 'BLOCKED', 'REJECTED', 'MUTED']);
  if (allowed.has(normalized)) {
    return normalized;
  }
  return 'ACTIVE';
}

function normalizeSource(source) {
  if (source === null || source === undefined) {
    return null;
  }
  const trimmed = source.toString().trim();
  return trimmed.length > 0 ? trimmed : null;
}

function toDate(value, fallback = null) {
  if (!value) {
    return fallback;
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value.toDate === 'function') {
    try {
      const date = value.toDate();
      if (date instanceof Date && !Number.isNaN(date.valueOf())) {
        return date;
      }
    } catch (error) {
      // fallthrough
    }
  }
  if (typeof value === 'number') {
    const date = new Date(value);
    return Number.isNaN(date.valueOf()) ? fallback : date;
  }
  if (typeof value === 'string') {
    const date = new Date(value);
    return Number.isNaN(date.valueOf()) ? fallback : date;
  }
  return fallback;
}

function buildFollowEdgePayload({ followerId, targetId, data }) {
  const createdAt = toDate(data?.createdAt, new Date());
  const updatedAt = toDate(data?.updatedAt || data?.lastUpdatedAt, createdAt);
  return {
    followerId,
    targetId,
    status: normalizeStatus(data?.status),
    source: normalizeSource(data?.source),
    createdAt,
    updatedAt,
  };
}

async function upsertFollowEdge(pool, payload) {
  const request = pool.request();
  request.input('FollowerUserId', mssql.NVarChar(128), payload.followerId);
  request.input('TargetUserId', mssql.NVarChar(128), payload.targetId);
  request.input('State', mssql.NVarChar(32), payload.status);
  request.input('Source', mssql.NVarChar(128), payload.source);
  request.input('CreatedAt', mssql.DateTime2, payload.createdAt);
  request.input('UpdatedAt', mssql.DateTime2, payload.updatedAt);

  const result = await request.query(`
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM dbo.FollowEdge WHERE FollowerUserId = @FollowerUserId AND TargetUserId = @TargetUserId)
BEGIN
  UPDATE dbo.FollowEdge
    SET State = @State,
        Source = @Source,
        UpdatedAt = @UpdatedAt
  WHERE FollowerUserId = @FollowerUserId AND TargetUserId = @TargetUserId;
  SELECT 'updated' AS Outcome;
END
ELSE
BEGIN
  INSERT INTO dbo.FollowEdge (FollowerUserId, TargetUserId, State, Source, CreatedAt, UpdatedAt)
  VALUES (@FollowerUserId, @TargetUserId, @State, @Source, @CreatedAt, @UpdatedAt);
  SELECT 'inserted' AS Outcome;
END;
`);

  return result.recordset?.[0]?.Outcome || 'unknown';
}

async function* defaultIterateFollowers(firestore, { batchSize, followerFilter }) {
  if (followerFilter) {
    yield followerFilter;
    return;
  }

  const FieldPath = admin.firestore.FieldPath;
  let lastId = null;

  while (true) {
    let query = firestore.collection('follows').orderBy(FieldPath.documentId()).limit(batchSize);
    if (lastId) {
      query = query.startAfter(lastId);
    }
    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    for (const doc of snapshot.docs) {
      yield doc.id;
    }

    const lastDoc = snapshot.docs[snapshot.docs.length - 1];
    lastId = lastDoc?.id || null;

    if (!lastId || snapshot.size < batchSize) {
      break;
    }
  }
}

async function backfillFollowEdges({
  firestore,
  pool,
  dryRun = false,
  batchSize,
  limit,
  followerFilter = null,
  stopAtFirstError = false,
  iterateFollowers = defaultIterateFollowers,
} = {}) {
  if (!firestore) {
    throw new Error('firestore instance is required');
  }
  if (!pool && !dryRun) {
    throw new Error('SQL pool is required when not running in dry-run mode');
  }

  const stats = {
    followersVisited: 0,
    processed: 0,
    inserted: 0,
    updated: 0,
    skipped: 0,
    failures: 0,
  };

  const iterator = iterateFollowers(firestore, { batchSize, followerFilter });

  for await (const followerId of iterator) {
    stats.followersVisited += 1;

    const followerRef = firestore.collection('follows').doc(followerId);
    const targetsSnapshot = await followerRef.collection('targets').get();

    if (!targetsSnapshot || targetsSnapshot.empty) {
      continue;
    }

    for (const doc of targetsSnapshot.docs) {
      if (limit != null && stats.processed >= limit) {
        return stats;
      }

      const rawData = typeof doc.data === 'function' ? doc.data() : doc.data;
      const payload = buildFollowEdgePayload({ followerId, targetId: doc.id, data: rawData });
      if (!payload.targetId) {
        stats.skipped += 1;
        continue;
      }

      stats.processed += 1;

      if (dryRun) {
        console.info('[backfill] dry-run follow edge', {
          followerId: payload.followerId,
          targetId: payload.targetId,
          status: payload.status,
          source: payload.source,
          createdAt: payload.createdAt.toISOString(),
          updatedAt: payload.updatedAt.toISOString(),
        });
        continue;
      }

      try {
        const outcome = await upsertFollowEdge(pool, payload);
        if (outcome === 'inserted') {
          stats.inserted += 1;
        } else if (outcome === 'updated') {
          stats.updated += 1;
        } else {
          stats.skipped += 1;
        }
      } catch (error) {
        stats.failures += 1;
        console.error('[backfill] failed follow edge', {
          followerId: payload.followerId,
          targetId: payload.targetId,
          error: error?.message,
        });
        if (stopAtFirstError) {
          throw error;
        }
      }
    }

    if (stats.processed > 0 && stats.processed % 200 === 0) {
      console.info('[backfill] progress', {
        processed: stats.processed,
        inserted: stats.inserted,
        updated: stats.updated,
        failures: stats.failures,
      });
    }
  }

  return stats;
}

async function main() {
  try {
    ensureFirebaseInitialized();
    const firestore = admin.firestore();
    const pool = await getSqlPool();

    console.info('[backfill] follow edges starting', {
      dryRun: isDryRun,
      batchSize,
      limit: limitEdges,
      followerFilter,
      strict: stopAtFirstError,
    });

    const stats = await backfillFollowEdges({
      firestore,
      pool,
      dryRun: isDryRun,
      batchSize,
      limit: limitEdges,
      followerFilter,
      stopAtFirstError,
    });

    console.info('[backfill] follow edges completed', stats);
  } catch (error) {
    console.error('[backfill] fatal error', error);
    process.exitCode = 1;
  } finally {
    if (sqlPoolPromise) {
      try {
        const pool = await sqlPoolPromise;
        await pool.close();
      } catch (error) {
        console.error('[backfill] failed to close SQL pool', error);
      }
    }
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  backfillFollowEdges,
  buildFollowEdgePayload,
  normalizeStatus,
  normalizeSource,
  toDate,
  upsertFollowEdge,
  defaultIterateFollowers,
};
