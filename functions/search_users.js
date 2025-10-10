const crypto = require('crypto');
const functions = require('firebase-functions');
const mssql = require('mssql');

const DEFAULT_REGION = process.env.SEARCH_REGION || 'europe-west1';
const REQUIRED_CLAIMS_VERSION = process.env.REQUIRED_CLAIMS_VERSION
  ? Number.parseInt(process.env.REQUIRED_CLAIMS_VERSION, 10)
  : null;
const HASH_SALT = process.env.SEARCH_SALT || 'rotate_me';
const DM_STRICT_SUGGESTION_LIMIT = Number.parseInt(
  process.env.DM_STRICT_SUGGESTION_LIMIT || '8',
  10,
);
const MAX_SQL_RETRIES = Math.max(
  0,
  Number.parseInt(process.env.SEARCH_SQL_MAX_RETRIES || '2', 10),
);
const SQL_RETRY_BASE_DELAY_MS = Math.max(
  25,
  Number.parseInt(process.env.SEARCH_SQL_RETRY_DELAY_MS || '50', 10),
);
const RAW_CORS_ALLOWLIST =
  process.env.SEARCH_CORS_ALLOWLIST ??
  process.env.SEARCH_CORS_ORIGINS ??
  process.env.SEARCH_CORS_ORIGIN ??
  '';

function parseCorsAllowlist(raw) {
  return String(raw || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
}

const PARSED_CORS_ALLOWLIST = parseCorsAllowlist(RAW_CORS_ALLOWLIST);
const CORS_ALLOW_ALL =
  PARSED_CORS_ALLOWLIST.length === 0 || PARSED_CORS_ALLOWLIST.includes('*');
const CORS_ALLOWED_ORIGINS = CORS_ALLOW_ALL
  ? []
  : PARSED_CORS_ALLOWLIST.filter((origin) => origin !== '*');

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

async function createSqlPool() {
  ensureSqlConfigValid();
  const pool = new mssql.ConnectionPool(sqlConfig);
  pool.on('error', (error) => {
    console.error('SQL pool error (auto-reset):', error);
    resetSqlPool().catch((resetError) => {
      console.error('SQL pool reset failure:', resetError);
    });
  });
  return pool.connect();
}

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

async function getSqlPool() {
  if (sqlPoolPromise) {
    try {
      const existingPool = await sqlPoolPromise;
      if (existingPool?.connected) {
        return existingPool;
      }
    } catch (error) {
      console.error('Existing SQL pool promise failed:', error);
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
    console.error('Error closing SQL pool during reset:', error);
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
      functions.logger.warn('search.users.sql_retry', {
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

function hashQuery(query) {
  return crypto.createHmac('sha256', HASH_SALT).update(query).digest('hex');
}

function decodeCursor(cursor) {
  if (!cursor) return { score: null, id: null };
  try {
    const decoded = Buffer.from(String(cursor), 'base64').toString('utf8');
    const parsed = JSON.parse(decoded);
    if (!parsed || typeof parsed !== 'object') {
      return { score: null, id: null };
    }
    return {
      score: parsed.s ?? null,
      id: parsed.id ?? null,
    };
  } catch (error) {
    return { score: null, id: null };
  }
}

function encodeCursor(score, id) {
  if (score === null || score === undefined || !id) {
    return null;
  }
  const payload = JSON.stringify({ s: Number(score), id });
  return Buffer.from(payload, 'utf8').toString('base64');
}

async function mapFirebaseUidToUserId(pool, firebaseUid) {
  const request = pool.request();
  request.input('firebaseUid', mssql.NVarChar(128), firebaseUid);
  const result = await request.query(`
    SELECT TOP (1) Id
    FROM dbo.Users
    WHERE firebaseUid = @firebaseUid
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
    insertRequest.input('endpoint', mssql.VarChar(16), endpointKey);
    insertRequest.input('ts', mssql.DateTime2(3), now);
    await insertRequest.query(`
      INSERT INTO dbo.SearchRate (UserId, Endpoint, Ts)
      VALUES (@userId, @endpoint, @ts)
    `);

    const countRequest = new mssql.Request(transaction);
    countRequest.input('userId', mssql.UniqueIdentifier, userId);
    countRequest.input('endpoint', mssql.VarChar(16), endpointKey);
    countRequest.input('since', mssql.DateTime2(3), since);
    const countResult = await countRequest.query(`
      SELECT COUNT(*) AS cnt
      FROM dbo.SearchRate
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
      console.error('Search rate limit rollback error:', rollbackError);
    }
    throw error;
  }
}

function normalizeQuery(raw) {
  return String(raw || '').trim().toLowerCase();
}

async function queryUsers(pool, params) {
  const {
    meId,
    query,
    limit,
    afterScore,
    afterId,
    mode,
    filters,
  } = params;

  const request = pool.request();
  request.input('me', mssql.UniqueIdentifier, meId);
  request.input('q', mssql.NVarChar(50), query);
  request.input('lim', mssql.Int, limit);
  request.input('mode', mssql.VarChar(8), mode);
  request.input('afterScore', mssql.Decimal(6, 3), afterScore ?? null);
  request.input('afterId', mssql.UniqueIdentifier, afterId ?? null);
  request.input('onlyVerified', mssql.Bit, filters.onlyVerified ? 1 : 0);
  request.input('onlyFollowing', mssql.Bit, filters.onlyFollowing ? 1 : 0);
  request.input('onlyNonFollowing', mssql.Bit, filters.onlyNotFollowing ? 1 : 0);

  const sql = `
;WITH Base AS (
  SELECT
    U.Id,
    U.Username,
    U.DisplayName,
    U.IsVerified,
    U.AvatarUrl,
    CAST(
      (CASE WHEN U.UsernameNorm LIKE @q + '%' THEN 2.0 ELSE 0.0 END) +
      (CASE WHEN U.DisplayNorm  LIKE @q + '%' THEN 1.0 ELSE 0.0 END) +
      (CASE WHEN U.IsVerified = 1 THEN 0.2 ELSE 0.0 END)
    AS DECIMAL(6,3)) AS Score,
    CASE
      WHEN @mode <> 'DM' THEN 1
      WHEN U.DmPolicy = 0 THEN 1
      WHEN U.DmPolicy = 1 AND EXISTS (
        SELECT 1
        FROM dbo.Follows f
        WHERE f.FollowerId = @me AND f.FollowedId = U.Id
      ) THEN 1
      ELSE 0
    END AS CanMessage
  FROM dbo.Users U
  WHERE (U.UsernameNorm LIKE @q + '%' OR U.DisplayNorm LIKE @q + '%')
    AND U.Id <> @me
    AND NOT EXISTS (
      SELECT 1 FROM dbo.UserBlocks b WHERE b.BlockerId = @me AND b.BlockedId = U.Id
    )
    AND NOT EXISTS (
      SELECT 1 FROM dbo.UserBlocks b WHERE b.BlockerId = U.Id AND b.BlockedId = @me
    )
    AND (@onlyVerified = 0 OR U.IsVerified = 1)
    AND (
      @onlyFollowing = 0 OR EXISTS (
        SELECT 1 FROM dbo.Follows f WHERE f.FollowerId = @me AND f.FollowedId = U.Id
      )
    )
    AND (
      @onlyNonFollowing = 0 OR NOT EXISTS (
        SELECT 1 FROM dbo.Follows f WHERE f.FollowerId = @me AND f.FollowedId = U.Id
      )
    )
)
SELECT TOP (@lim)
  B.Id,
  B.Username,
  B.DisplayName,
  B.IsVerified,
  B.AvatarUrl,
  B.Score,
  B.CanMessage,
  ISNULL(M.MutualCount, 0) AS MutualCount
FROM Base B
OUTER APPLY (
  SELECT COUNT(*) AS MutualCount
  FROM dbo.Follows f1
  INNER JOIN dbo.Follows f2
    ON f2.FollowerId = f1.FollowedId AND f2.FollowedId = B.Id
  WHERE f1.FollowerId = @me
) AS M
WHERE
  (@afterScore IS NULL AND @afterId IS NULL)
  OR (B.Score < @afterScore OR (B.Score = @afterScore AND B.Id < @afterId))
ORDER BY B.Score DESC, B.Id DESC;
  `;

  const result = await request.query(sql);
  return result.recordset.map((row) => ({
    id: row.Id,
    username: row.Username,
    displayName: row.DisplayName,
    verified: Boolean(row.IsVerified),
    avatarUrl: row.AvatarUrl,
    score: Number(row.Score),
    canMessage: row.CanMessage === 1,
    mutualCount: Number(row.MutualCount ?? 0),
  }));
}

function determineRateLimit(limit, cursorProvided) {
  const isSuggestion = !cursorProvided && limit <= DM_STRICT_SUGGESTION_LIMIT;
  return {
    endpoint: isSuggestion ? 'suggest' : 'full',
    limitPerMinute: isSuggestion ? 30 : 20,
    strictDm: isSuggestion,
  };
}

function buildFilters(raw) {
  const filters = raw && typeof raw === 'object' ? raw : {};
  return {
    onlyVerified: Boolean(filters.onlyVerified),
    onlyFollowing: Boolean(filters.onlyFollowing),
    onlyNotFollowing: Boolean(filters.onlyNotFollowing),
  };
}

function applyCors(req, res) {
  res.set('Vary', 'Origin');

  const origin = req.headers.origin;
  const allow = CORS_ALLOW_ALL || !origin || CORS_ALLOWED_ORIGINS.includes(origin);

  if (!allow) {
    return false;
  }

  if (origin && (CORS_ALLOW_ALL || CORS_ALLOWED_ORIGINS.includes(origin))) {
    res.set('Access-Control-Allow-Origin', origin);
    res.set('Access-Control-Allow-Credentials', 'true');
  } else if (!origin && CORS_ALLOW_ALL) {
    res.set('Access-Control-Allow-Origin', '*');
  }

  const requestedHeaders = req.headers['access-control-request-headers'];
  if (requestedHeaders) {
    res.set('Access-Control-Allow-Headers', requestedHeaders);
  } else {
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  }

  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Max-Age', '300');

  return true;
}

function createHandler(admin) {
  const auth = admin.auth();

  return functions.region(DEFAULT_REGION).https.onRequest(async (req, res) => {
    const corsAllowed = applyCors(req, res);
    if (!corsAllowed) {
      res.status(403).json({ error: 'cors_rejected' });
      return;
    }
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method_not_allowed' });
      return;
    }

    const startedAt = Date.now();

    try {
      const authHeader = req.headers.authorization || '';
      const token = authHeader.startsWith('Bearer ')
        ? authHeader.slice('Bearer '.length)
        : null;
      if (!token) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }

      let decoded;
      try {
        decoded = await auth.verifyIdToken(token);
      } catch (error) {
        res.status(401).json({ error: 'unauthorized' });
        return;
      }

      if (!decoded.email_verified) {
        res.status(401).json({ error: 'email_unverified' });
        return;
      }

      if (
        REQUIRED_CLAIMS_VERSION !== null &&
        Number(decoded.claims_version ?? 0) !== REQUIRED_CLAIMS_VERSION
      ) {
        res.status(409).json({ error: 'claims_version_mismatch' });
        return;
      }

      const body = req.body && typeof req.body === 'object' ? req.body : {};
      const mode = body.scope === 'DM' ? 'DM' : 'GLOBAL';
      const query = normalizeQuery(body.query);
      const requestedLimit = Number.parseInt(body.limit ?? 8, 10);
      const limit = Number.isNaN(requestedLimit) ? 8 : Math.min(Math.max(requestedLimit, 1), 50);
      const cursor = body.cursor || null;
      const filters = buildFilters(body.filters);

      if (query.length < 2) {
        res.status(400).json({ error: 'short_query' });
        return;
      }

      const { score: afterScore, id: afterId } = decodeCursor(cursor);

      const { endpoint, limitPerMinute, strictDm } = determineRateLimit(limit, Boolean(cursor));

      let rows;
      try {
        const outcome = await runWithSql(async (pool) => {
          const myUserId = await mapFirebaseUidToUserId(pool, decoded.uid);
          const allowed = await rateLimit(pool, myUserId, endpoint, limitPerMinute);
          if (!allowed) {
            return { rateLimited: true, rows: [] };
          }

          const sqlLimit = strictDm ? Math.min(limit * 3, 60) : limit;
          const users = await queryUsers(pool, {
            meId: myUserId,
            query,
            limit: sqlLimit,
            afterScore,
            afterId,
            mode,
            filters,
          });

          return { rateLimited: false, rows: users };
        });

        if (outcome.rateLimited) {
          res.status(429).json({ error: 'rate_limited' });
          return;
        }

        rows = outcome.rows;
      } catch (error) {
        if (error && error.message === 'USER_NOT_MAPPED') {
          res.status(401).json({ error: 'user_not_found' });
          return;
        }
        throw error;
      }

      let items = rows;
      let dmPolicyBlocked = false;

      if (mode === 'DM' && strictDm) {
        const filtered = rows.filter((row) => row.canMessage);
        dmPolicyBlocked = rows.length > 0 && filtered.length === 0;
        items = filtered.slice(0, limit);
      } else {
        items = rows.slice(0, limit);
      }

      if (mode === 'DM' && strictDm && dmPolicyBlocked) {
        res.status(403).json({ error: 'dm_policy_restriction' });
        return;
      }

      const finalItems = items.map((item) => ({
        uid: item.id,
        displayName: item.displayName,
        username: item.username,
        verified: item.verified,
        avatar: item.avatarUrl,
        canMessage: mode === 'DM' ? Boolean(item.canMessage) : undefined,
        mutualCount: item.mutualCount,
      }));

      const lastItem = items[items.length - 1] || null;
      const nextCursor = lastItem ? encodeCursor(lastItem.score, lastItem.id) : null;
      const tookMs = Date.now() - startedAt;

      functions.logger.log('search.users', {
        mode,
        tookMs,
        count: finalItems.length,
        cursorProvided: Boolean(cursor),
        hash: hashQuery(query),
      });

      res.json({
        items: finalItems,
        nextCursor,
        tookMs,
        meta: { scope: mode },
      });
    } catch (error) {
      console.error('searchUsers error:', error);
      res.status(500).json({ error: 'server_error' });
    }
  });
}

module.exports = {
  createSearchUsersHandler: createHandler,
};
