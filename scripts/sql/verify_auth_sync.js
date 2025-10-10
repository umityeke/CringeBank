#!/usr/bin/env node

/**
 * verify_auth_sync.js
 * --------------------
 * Runs the auth→SQL migration stored procedure (optional) and reports mismatches between
 * Firebase Authentication and dbo.Users.auth_uid records.
 *
 * Usage examples:
 *   node scripts/sql/verify_auth_sync.js
 *   node scripts/sql/verify_auth_sync.js --dry-run --limit=500
 *   node scripts/sql/verify_auth_sync.js --skip-migration --output=json
 *   node scripts/sql/verify_auth_sync.js --migration=dbo.sp_MigrateAuthUids
 *
 * Environment variables (override CLI defaults where noted):
 *   SQLSERVER_HOST, SQLSERVER_USER, SQLSERVER_PASS, SQLSERVER_DB, SQLSERVER_PORT,
 *   SQLSERVER_POOL_MAX, SQLSERVER_POOL_MIN, SQLSERVER_POOL_IDLE,
 *   SQLSERVER_ENCRYPT, SQLSERVER_TRUST_CERT
 *   AUTH_SYNC_LIMIT, AUTH_SYNC_BATCH_SIZE, AUTH_SYNC_MIGRATION_PROC
 *   GOOGLE_APPLICATION_CREDENTIALS (or equivalent firebase-admin credentials)
 */

const admin = require('firebase-admin');
const mssql = require('mssql');

const argv = process.argv.slice(2);

function hasFlag(flag) {
  return argv.includes(flag);
}

function getOption(name, fallback) {
  const prefix = `--${name}=`;
  const raw = argv.find((arg) => arg.startsWith(prefix));
  if (raw) {
    return raw.slice(prefix.length);
  }
  return fallback;
}

const isDryRun = hasFlag('--dry-run');
const skipMigration = hasFlag('--skip-migration');
const outputJson = getOption('output', 'table') === 'json';
const batchSize = Number.parseInt(getOption('batch-size', process.env.AUTH_SYNC_BATCH_SIZE || '500'), 10);
const limit = (() => {
  const value = getOption('limit', process.env.AUTH_SYNC_LIMIT || null);
  if (value == null) return null;
  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? null : parsed;
})();
const migrationProc = getOption('migration', process.env.AUTH_SYNC_MIGRATION_PROC || 'dbo.sp_MigrateAuthUids');

if (Number.isNaN(batchSize) || batchSize <= 0 || batchSize > 1000) {
  console.error('[verify-auth-sync] Invalid batch-size; must be between 1 and 1000.');
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
    throw new Error(`Missing SQL configuration variables: ${missing.join(', ')}`);
  }
}

let poolPromise;
async function getSqlPool() {
  if (!poolPromise) {
    ensureSqlConfigValid();
    poolPromise = (async () => {
      const pool = new mssql.ConnectionPool(sqlConfig);
      pool.on('error', (error) => console.error('[verify-auth-sync] SQL pool error', error));
      await pool.connect();
      return pool;
    })();
  }
  return poolPromise;
}

async function runMigrationIfNeeded(pool) {
  if (skipMigration) {
    console.info('[verify-auth-sync] Skipping migration execution (--skip-migration).');
    return { executed: false };
  }

  if (!migrationProc) {
    console.warn('[verify-auth-sync] Migration procedure not specified; skipping execution.');
    return { executed: false };
  }

  console.info('[verify-auth-sync] Executing migration stored procedure', {
    migrationProc,
    dryRun: isDryRun,
  });

  const request = pool.request();
  if (isDryRun) {
    request.input('DryRun', mssql.Bit, true);
  }

  const start = Date.now();
  const result = await request.execute(migrationProc).catch((error) => {
    error.message = `Migration stored procedure failed (${migrationProc}): ${error.message}`;
    throw error;
  });
  const elapsedMs = Date.now() - start;

  console.info('[verify-auth-sync] Migration completed', {
    elapsedMs,
    returnValue: result.returnValue,
  });

  return {
    executed: true,
    elapsedMs,
    returnValue: result.returnValue,
  };
}

async function fetchFirebaseUsers() {
  ensureFirebaseInitialized();
  const auth = admin.auth();
  const users = [];
  let pageToken;

  while (true) {
    if (limit != null && users.length >= limit) {
      break;
    }

    const remaining = limit != null ? Math.max(Math.min(batchSize, limit - users.length), 1) : batchSize;
    const page = await auth.listUsers(remaining, pageToken);

    for (const user of page.users) {
      users.push({
        uid: user.uid,
        email: user.email,
        disabled: user.disabled,
        createdAt: user.metadata?.creationTime,
      });
      if (limit != null && users.length >= limit) {
        break;
      }
    }

    pageToken = page.pageToken;
    if (!pageToken) {
      break;
    }
  }

  return {
    users,
    truncated: limit != null && users.length >= limit,
  };
}

async function fetchSqlAuthRecords(pool) {
  const query = `
    SELECT
      u.Id AS userId,
      u.auth_uid AS authUid,
      u.email AS email,
      u.username AS username,
      u.date_created AS dateCreated
    FROM dbo.Users u
    WHERE u.auth_uid IS NOT NULL AND LTRIM(RTRIM(u.auth_uid)) <> '';
  `;

  const duplicatesQuery = `
    SELECT
      auth_uid AS authUid,
      COUNT(*) AS count
    FROM dbo.Users
    WHERE auth_uid IS NOT NULL AND LTRIM(RTRIM(auth_uid)) <> ''
    GROUP BY auth_uid
    HAVING COUNT(*) > 1;
  `;

  const [recordsResult, duplicatesResult] = await Promise.all([
    pool.request().query(query),
    pool.request().query(duplicatesQuery),
  ]);

  return {
    records: recordsResult.recordset || [],
    duplicates: duplicatesResult.recordset || [],
  };
}

function buildComparison({ firebaseUsers, sqlRecords }) {
  const firebaseMap = new Map();
  const firebaseUidSet = new Set();
  for (const user of firebaseUsers) {
    firebaseMap.set(user.uid, user);
    firebaseUidSet.add(user.uid);
  }

  const sqlMap = new Map();
  const sqlUidSet = new Set();
  for (const record of sqlRecords) {
    if (!record.authUid) {
      continue;
    }
    const authUid = record.authUid.trim();
    sqlUidSet.add(authUid);
    sqlMap.set(authUid, record);
  }

  const missingInSql = [];
  for (const user of firebaseUsers) {
    if (!sqlUidSet.has(user.uid)) {
      missingInSql.push({
        uid: user.uid,
        email: user.email,
        disabled: user.disabled,
        createdAt: user.createdAt,
      });
    }
  }

  const missingInFirebase = [];
  for (const record of sqlRecords) {
    const authUid = record.authUid?.trim();
    if (authUid && !firebaseUidSet.has(authUid)) {
      missingInFirebase.push({
        uid: authUid,
        userId: record.userId,
        email: record.email,
        username: record.username,
        dateCreated: record.dateCreated,
      });
    }
  }

  return {
    missingInSql,
    missingInFirebase,
  };
}

function summarize({ firebaseUsers, sqlRecords, missingInSql, missingInFirebase, duplicates, migrationInfo }) {
  const summary = {
    totals: {
      firebaseUsers: firebaseUsers.length,
      sqlUsers: sqlRecords.length,
      missingInSql: missingInSql.length,
      missingInFirebase: missingInFirebase.length,
      duplicates: duplicates.length,
    },
    sampleMissingInSql: missingInSql.slice(0, 20),
    sampleMissingInFirebase: missingInFirebase.slice(0, 20),
    duplicates: duplicates.slice(0, 20),
    migration: migrationInfo,
  };

  if (outputJson) {
    console.log(JSON.stringify(summary, null, 2));
  } else {
    console.log('\n[verify-auth-sync] Summary');
    console.table([summary.totals]);

    if (missingInSql.length > 0) {
      console.log('\n[verify-auth-sync] Firebase users missing in SQL (first 20):');
      console.table(summary.sampleMissingInSql);
    }

    if (missingInFirebase.length > 0) {
      console.log('\n[verify-auth-sync] SQL rows without Firebase counterpart (first 20):');
      console.table(summary.sampleMissingInFirebase);
    }

    if (duplicates.length > 0) {
      console.log('\n[verify-auth-sync] Duplicate auth_uid rows (first 20):');
      console.table(summary.duplicates);
    }

    if (migrationInfo?.executed) {
      console.log('\n[verify-auth-sync] Migration execution:', migrationInfo);
    } else {
      console.log('\n[verify-auth-sync] Migration execution skipped.');
    }
  }

  const hasMismatch =
    summary.totals.missingInSql > 0 || summary.totals.missingInFirebase > 0 || summary.totals.duplicates > 0;
  if (hasMismatch) {
    console.error('\n[verify-auth-sync] Mismatches detected. Review the tables above.');
    process.exitCode = 2;
  }
}

async function main() {
  console.info('[verify-auth-sync] Starting', {
    dryRun: isDryRun,
    skipMigration,
    migrationProc,
    batchSize,
    limit,
    output: outputJson ? 'json' : 'table',
  });

  try {
    const pool = await getSqlPool();
    const migrationInfo = await runMigrationIfNeeded(pool);

    const [{ users: firebaseUsers, truncated }, sqlData] = await Promise.all([
      fetchFirebaseUsers(),
      fetchSqlAuthRecords(pool),
    ]);

    if (truncated && !outputJson) {
      console.warn('[verify-auth-sync] Firebase list truncated by limit; totals reflect limited scan.');
    }

    const comparison = buildComparison({ firebaseUsers, sqlRecords: sqlData.records });
    summarize({
      firebaseUsers,
      sqlRecords: sqlData.records,
      missingInSql: comparison.missingInSql,
      missingInFirebase: comparison.missingInFirebase,
      duplicates: sqlData.duplicates,
      migrationInfo,
    });
  } catch (error) {
    console.error('[verify-auth-sync] Failed', error);
    process.exitCode = 1;
  } finally {
    if (poolPromise) {
      const pool = await poolPromise.catch(() => null);
      if (pool) {
        await pool.close().catch((error) => console.error('[verify-auth-sync] Error closing pool', error));
      }
    }
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  buildComparison,
};
