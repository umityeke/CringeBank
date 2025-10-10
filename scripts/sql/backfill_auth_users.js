#!/usr/bin/env node

/**
 * Backfill Firebase Auth users into SQL dbo.Users table via dbo.sp_EnsureUser.
 *
 * Usage:
 *   node scripts/sql/backfill_auth_users.js --dry-run
 *   node scripts/sql/backfill_auth_users.js --batch-size=500 --resume-token=<pageToken>
 *
 * Required environment variables:
 *   - GOOGLE_APPLICATION_CREDENTIALS (or alternative firebase-admin initialization vars)
 *   - SQLSERVER_HOST, SQLSERVER_USER, SQLSERVER_PASS, SQLSERVER_DB
 *   - Optional: SQLSERVER_PORT, SQLSERVER_POOL_MAX, SQLSERVER_POOL_MIN, SQLSERVER_POOL_IDLE,
 *               SQLSERVER_ENCRYPT, SQLSERVER_TRUST_CERT
 */

const admin = require('firebase-admin');
const mssql = require('mssql');

const argv = process.argv.slice(2);

const parseFlag = (flag) => argv.some((arg) => arg === flag);
const parseOption = (name, defaultValue) => {
  const prefix = `--${name}=`;
  const raw = argv.find((arg) => arg.startsWith(prefix));
  if (!raw) {
    return defaultValue;
  }
  return raw.slice(prefix.length);
};

const isDryRun = parseFlag('--dry-run');
const batchSize = Number.parseInt(parseOption('batch-size', process.env.BACKFILL_BATCH_SIZE || '250'), 10);
const resumeToken = parseOption('resume-token', process.env.BACKFILL_RESUME_TOKEN || null);
const limitUsers = parseOption('limit', process.env.BACKFILL_LIMIT || null);
const stopAtFirstError = parseFlag('--strict') || process.env.BACKFILL_STRICT === 'true';

if (Number.isNaN(batchSize) || batchSize <= 0 || batchSize > 1000) {
  console.error('Invalid batch-size; must be between 1 and 1000.');
  process.exitCode = 1;
  return;
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

function resolveUsername({ authUser, profileDoc }) {
  const profileData = profileDoc?.data?.();
  const username = profileData?.username || profileData?.usernameLower || authUser.displayName || authUser.email;
  if (username) {
    return username.toString().trim() || authUser.uid;
  }
  return authUser.uid;
}

function resolveDisplayName({ authUser, profileDoc }) {
  const profileData = profileDoc?.data?.();
  return (
    profileData?.displayName ||
    profileData?.fullName ||
    authUser.displayName ||
    profileData?.username ||
    authUser.email?.split('@')[0] ||
    authUser.uid
  );
}

function normalizeEmail(email) {
  return email ? email.trim().toLowerCase() : null;
}

async function runBackfill() {
  ensureFirebaseInitialized();
  const auth = admin.auth();
  const firestore = admin.firestore();
  const pool = await getSqlPool();

  let processed = 0;
  let created = 0;
  let updated = 0;
  let failures = 0;
  let nextPageToken = resumeToken || undefined;
  const limit = limitUsers ? Number.parseInt(limitUsers, 10) : null;

  console.info('[backfill] starting', {
    dryRun: isDryRun,
    batchSize,
    resumeToken,
    limit,
  });

  try {
    do {
      if (limit != null && processed >= limit) {
        console.info('[backfill] limit reached', { processed, limit });
        break;
      }

      const remaining = limit != null ? Math.min(batchSize, limit - processed) : batchSize;
      const result = await auth.listUsers(Math.max(remaining, 1), nextPageToken);
      nextPageToken = result.pageToken;

      for (const user of result.users) {
        if (limit != null && processed >= limit) {
          break;
        }

        processed += 1;
        try {
          const profileSnap = await firestore.collection('users').doc(user.uid).get().catch((error) => {
            console.warn('[backfill] firestore read failed', { uid: user.uid, error: error?.message });
            return null;
          });

          const username = resolveUsername({ authUser: user, profileDoc: profileSnap });
          const displayName = resolveDisplayName({ authUser: user, profileDoc: profileSnap });
          const email = normalizeEmail(user.email);

          if (isDryRun) {
            console.info('[backfill] dry-run ensureSqlUser', {
              uid: user.uid,
              username,
              displayName,
              email,
            });
            continue;
          }

          const request = pool.request();
          request.input('AuthUid', mssql.NVarChar(64), user.uid);
          request.input('Email', mssql.NVarChar(256), email);
          request.input('Username', mssql.NVarChar(64), username);
          request.input('DisplayName', mssql.NVarChar(128), displayName);
          request.output('UserId', mssql.Int);
          request.output('Created', mssql.Bit);

          const result = await request.execute('dbo.sp_EnsureUser');
          const createdFlag = result.output?.Created === true || result.output?.Created === 1;
          if (createdFlag) {
            created += 1;
          } else {
            updated += 1;
          }

          if (processed % 100 === 0) {
            console.info('[backfill] progress', {
              processed,
              created,
              updated,
              failures,
              nextPageToken,
            });
          }
        } catch (error) {
          failures += 1;
          console.error('[backfill] failed', {
            uid: user.uid,
            error: error?.message,
            code: error?.code,
          });
          if (stopAtFirstError) {
            throw error;
          }
        }
      }
    } while (nextPageToken);
  } finally {
    if (sqlPoolPromise) {
      try {
        const pool = await sqlPoolPromise;
        await pool.close();
      } catch (error) {
        console.error('Error closing SQL pool:', error);
      }
    }
  }

  console.info('[backfill] completed', {
    processed,
    created,
    updated,
    failures,
    resumeToken: nextPageToken || null,
  });

  if (failures > 0) {
    process.exitCode = 1;
  }
}

runBackfill().catch((error) => {
  console.error('[backfill] fatal error', error);
  process.exitCode = 1;
});
