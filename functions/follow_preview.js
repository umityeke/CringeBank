const functions = require('firebase-functions');
const mssql = require('mssql');

const DEFAULT_REGION = process.env.FOLLOW_PREVIEW_REGION || 'europe-west1';
const MAX_SQL_RETRIES = Math.max(
  0,
  Number.parseInt(process.env.FOLLOW_PREVIEW_SQL_MAX_RETRIES || '2', 10),
);
const SQL_RETRY_BASE_DELAY_MS = Math.max(
  25,
  Number.parseInt(process.env.FOLLOW_PREVIEW_SQL_RETRY_DELAY_MS || '75', 10),
);
const RAW_LIMIT = Number.parseInt(process.env.FOLLOW_PREVIEW_DEFAULT_LIMIT || '12', 10);
const DEFAULT_LIMIT = Number.isNaN(RAW_LIMIT) ? 12 : Math.min(Math.max(RAW_LIMIT, 1), 50);
const RATE_LIMIT_PER_MINUTE = Math.max(
  1,
  Number.parseInt(process.env.FOLLOW_PREVIEW_RATE_LIMIT_PER_MINUTE || '30', 10),
);
const RATE_LIMIT_TABLE = process.env.FOLLOW_PREVIEW_RATE_TABLE || 'FollowPreviewRate';

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

let sqlPoolPromise = null;

function ensureSqlConfigValid() {
  const missing = [];
  if (!sqlConfig.server) missing.push('SQLSERVER_HOST');
  if (!sqlConfig.user) missing.push('SQLSERVER_USER');
  if (!sqlConfig.password) missing.push('SQLSERVER_PASS');
  if (!sqlConfig.database) missing.push('SQLSERVER_DB');
  if (missing.length > 0) {
    throw new Error(`Missing SQL Server configuration: ${missing.join(', ')}`);
  }
}

async function createSqlPool() {
  ensureSqlConfigValid();
  const pool = new mssql.ConnectionPool(sqlConfig);
  pool.on('error', (error) => {
    console.error('followPreview.sql_pool_error', error);
    resetSqlPool().catch((resetError) => {
      console.error('followPreview.sql_pool_reset_failed', resetError);
    });
  });
  return pool.connect();
}

async function getSqlPool() {
  if (sqlPoolPromise) {
    try {
      const existing = await sqlPoolPromise;
      if (existing?.connected) {
        return existing;
      }
    } catch (error) {
      console.error('followPreview.sql_pool_reuse_failed', error);
    }
    sqlPoolPromise = null;
  }
  sqlPoolPromise = createSqlPool();
  return sqlPoolPromise;
}

async function resetSqlPool() {
  if (!sqlPoolPromise) {
    return;
  }
  const currentPromise = sqlPoolPromise;
  sqlPoolPromise = null;
  try {
    const pool = await currentPromise;
    if (pool?.close) {
      await pool.close();
    }
  } catch (error) {
    console.error('followPreview.sql_pool_close_failed', error);
  }
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isRetryableSqlError(error) {
  if (!error) return false;
  if (error.originalError && isRetryableSqlError(error.originalError)) {
    return true;
  }

  const retryableCodes = new Set([
    'ETIMEOUT',
    'ESOCKET',
    'ECONNRESET',
    'ECONNCLOSED',
    'EPIPE',
    'ENOTOPEN',
  ]);

  if (error.code && retryableCodes.has(error.code)) {
    return true;
  }

  const retryableNames = new Set([
    'ConnectionError',
    'ConnectionTimeoutError',
    'PreparedStatementError',
  ]);
  if (error.name && retryableNames.has(error.name)) {
    return true;
  }

  const message = String(error.message || '');
  if (/Connection is closed|Failed to connect|socket hang up/i.test(message)) {
    return true;
  }

  return false;
}

async function runWithSql(operation, { retries = MAX_SQL_RETRIES } = {}) {
  let attempt = 0;
  let lastError;

  while (attempt <= retries) {
    try {
      const pool = await getSqlPool();
      return await operation(pool);
    } catch (error) {
      lastError = error;
      const shouldRetry = isRetryableSqlError(error) && attempt < retries;
      if (!shouldRetry) {
        throw error;
      }

      const delayMs = SQL_RETRY_BASE_DELAY_MS * (attempt + 1);
      functions.logger.warn('followPreview.sql_retry', {
        attempt: attempt + 1,
        retries,
        code: error.code,
        name: error.name,
      });

      await resetSqlPool();
      await delay(delayMs);
      attempt += 1;
    }
  }

  throw lastError;
}

async function mapFirebaseUidToUserId(pool, firebaseUid) {
  const request = pool.request();
  request.input('firebaseUid', mssql.NVarChar(128), firebaseUid);
  const result = await request.query(`
    SELECT TOP (1) Id
    FROM dbo.Users
    WHERE FirebaseUid = @firebaseUid
  `);
  if (result.recordset.length === 0) {
    throw new Error('USER_NOT_MAPPED');
  }
  return result.recordset[0].Id;
}

async function rateLimit(pool, userId, endpointKey, limitPerMinute) {
  const now = new Date();
  const since = new Date(now.getTime() - 60_000);
  const transaction = new mssql.Transaction(pool);
  await transaction.begin(mssql.ISOLATION_LEVEL.SERIALIZABLE);
  try {
    const insertRequest = new mssql.Request(transaction);
    insertRequest.input('userId', mssql.UniqueIdentifier, userId);
    insertRequest.input('endpoint', mssql.VarChar(32), endpointKey);
    insertRequest.input('ts', mssql.DateTime2(3), now);
    await insertRequest.query(`
      INSERT INTO dbo.${RATE_LIMIT_TABLE} (UserId, Endpoint, Ts)
      VALUES (@userId, @endpoint, @ts)
    `);

    const countRequest = new mssql.Request(transaction);
    countRequest.input('userId', mssql.UniqueIdentifier, userId);
    countRequest.input('endpoint', mssql.VarChar(32), endpointKey);
    countRequest.input('since', mssql.DateTime2(3), since);
    const countResult = await countRequest.query(`
      SELECT COUNT(*) AS cnt
      FROM dbo.${RATE_LIMIT_TABLE}
      WHERE UserId = @userId AND Endpoint = @endpoint AND Ts >= @since
    `);
    const count = countResult.recordset[0]?.cnt ?? 0;
    if (count > limitPerMinute) {
      await transaction.rollback();
      return false;
    }

    await transaction.commit();
    return true;
  } catch (error) {
    try {
      await transaction.rollback();
    } catch (rollbackError) {
      console.error('followPreview.ratelimit.rollback_failed', rollbackError);
    }
    throw error;
  }
}

function normalizeUid(raw, fallback) {
  const normalized = String(raw || '').trim();
  return normalized || fallback;
}

function clampLimit(rawLimit) {
  const parsed = Number.parseInt(rawLimit ?? '', 10);
  if (Number.isNaN(parsed)) {
    return DEFAULT_LIMIT;
  }
  return Math.min(Math.max(parsed, 1), 50);
}

function sanitizeCursor(cursor) {
  if (!cursor) {
    return null;
  }
  return String(cursor).trim() || null;
}

function mapRowToPayload(row) {
  return {
    uid: row.TargetFirebaseUid || row.TargetUid || row.TargetId || null,
    username: row.Username || null,
    displayName: row.DisplayName || row.Username || null,
    avatar: row.AvatarUrl || null,
    verified: Boolean(row.IsVerified || row.Verified),
    isPrivate: Boolean(row.IsPrivate || row.PrivateProfile),
    followersCount: Number(row.FollowersCount ?? row.FollowerCount ?? 0),
    followingCount: Number(row.FollowingCount ?? 0),
    mutualCount: Number(row.MutualCount ?? 0),
    followedAt: row.FollowedAt instanceof Date
      ? row.FollowedAt.toISOString()
      : row.FollowedAt ?? null,
    cursorToken: row.CursorToken || null,
  };
}

function createHandler(admin) {
  return functions.region(DEFAULT_REGION).https.onCall(async (data, context) => {
    if (!context.app) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'app_check_required',
      );
    }

    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Bu işlemi gerçekleştirmek için giriş yapmalısınız.',
      );
    }

    const viewerUid = context.auth.uid;
    const targetUid = normalizeUid(data?.targetUid, viewerUid);
    const limit = clampLimit(data?.limit);
    const cursor = sanitizeCursor(data?.cursor);

    const startedAt = Date.now();

    try {
      const outcome = await runWithSql(async (pool) => {
        const viewerId = await mapFirebaseUidToUserId(pool, viewerUid);
        const targetId = await mapFirebaseUidToUserId(pool, targetUid);

        const allowed = await rateLimit(pool, viewerId, 'follow_preview', RATE_LIMIT_PER_MINUTE);
        if (!allowed) {
          return { rateLimited: true };
        }

        const request = pool.request();
        request.input('ViewerId', mssql.UniqueIdentifier, viewerId);
        request.input('TargetId', mssql.UniqueIdentifier, targetId);
        request.input('Limit', mssql.Int, limit);
        request.input('CursorToken', mssql.VarChar(128), cursor);
        const result = await request.execute('dbo.sp_GetFollowingPreview');

        const rows = result.recordset ?? [];
        const nextCursor = result.output?.NextCursor ?? rows[rows.length - 1]?.CursorToken ?? null;

        return {
          rateLimited: false,
          rows,
          nextCursor,
        };
      });

      if (outcome.rateLimited) {
        throw new functions.https.HttpsError('resource-exhausted', 'rate_limited');
      }

      const items = (outcome.rows ?? []).map(mapRowToPayload).filter((item) => item.uid);
      const tookMs = Date.now() - startedAt;

      functions.logger.log('followPreview.success', {
        viewerUid,
        targetUid,
        limit,
        count: items.length,
        cursorProvided: Boolean(cursor),
        tookMs,
      });

      return {
        items,
        nextCursor: outcome.nextCursor ?? null,
        tookMs,
        meta: {
          targetUid,
          limit,
        },
      };
    } catch (error) {
      if (error?.message === 'USER_NOT_MAPPED') {
        throw new functions.https.HttpsError('not-found', 'user_not_found');
      }
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      console.error('followPreview.unexpected_error', error);
      throw new functions.https.HttpsError('internal', 'server_error');
    }
  });
}

module.exports = {
  createFollowPreviewHandler: createHandler,
};
