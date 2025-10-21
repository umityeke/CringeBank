const functions = require('../regional_functions');
const admin = require('firebase-admin');
const sql = require('mssql');
const { getPool } = require('../sql_gateway/pool');
const { sendSlackAlert, logStructured } = require('../utils/alerts');

if (!admin.apps.length) {
  admin.initializeApp();
}

const firestore = admin.firestore();
const FieldPath = admin.firestore.FieldPath;

const DEFAULT_REGION = process.env.PROFILE_RECON_REGION || 'europe-west1';
const DEFAULT_SCHEDULE = process.env.PROFILE_RECON_SCHEDULE || '15 3 * * *';
const DEFAULT_TIMEZONE = process.env.PROFILE_RECON_TIMEZONE || 'Europe/Istanbul';

function parsePositiveInt(value, fallback) {
  if (value === undefined || value === null) {
    return fallback;
  }

  if (typeof value === 'string' && value.trim().toLowerCase() === 'all') {
    return Number.MAX_SAFE_INTEGER;
  }

  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }

  return parsed;
}

const BATCH_SIZE = parsePositiveInt(process.env.PROFILE_RECON_BATCH_SIZE, 200);
const MAX_DOCS = parsePositiveInt(process.env.PROFILE_RECON_MAX_DOCS, 1000);
const SAMPLE_LIMIT = parsePositiveInt(process.env.PROFILE_RECON_SAMPLE_LIMIT, 20);

function normalizeString(value, { toLower = false } = {}) {
  if (value === undefined || value === null) {
    return null;
  }

  const str = value.toString().trim();
  if (str.length === 0) {
    return null;
  }

  return toLower ? str.toLowerCase() : str;
}

function normalizeEmail(value) {
  return normalizeString(value, { toLower: true });
}

function toIsoString(value) {
  if (!value) {
    return null;
  }

  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value.toISOString();
  }

  if (typeof value === 'object' && typeof value.toDate === 'function') {
    const date = value.toDate();
    return Number.isNaN(date.getTime()) ? null : date.toISOString();
  }

  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) {
      return null;
    }
    const date = new Date(trimmed);
    return Number.isNaN(date.getTime()) ? null : date.toISOString();
  }

  return null;
}

function mapFirestoreProfile(doc) {
  const data = doc.data() || {};
  const rawSqlUserId = data.sqlUserId ?? data.sqlUserID ?? data.userId ?? null;

  let sqlUserId = null;
  if (rawSqlUserId !== null && rawSqlUserId !== undefined) {
    const parsed = Number(rawSqlUserId);
    sqlUserId = Number.isFinite(parsed) ? parsed : null;
  }

  return {
    authUid: doc.id,
    sqlUserId,
    username: normalizeString(data.username ?? data.handle ?? data.userName ?? null),
    displayName: normalizeString(
      data.displayName ?? data.fullName ?? data.name ?? data.username ?? null,
    ),
    email: normalizeEmail(data.email ?? data.emailLower ?? null),
    updatedAt: toIsoString(data.updatedAtUtc ?? data.updatedAt ?? data.lastSyncedAt),
  };
}

function mapSqlProfile(row) {
  if (!row) {
    return null;
  }

  return {
    authUid: normalizeString(row.AuthUid, { toLower: false }),
    id: row.Id ?? null,
    username: normalizeString(row.Username),
    displayName: normalizeString(row.DisplayName),
    email: normalizeEmail(row.Email),
    updatedAt: toIsoString(row.UpdatedAt ?? row.updated_at ?? null),
  };
}

function compareProfileRecords(firestoreProfile, sqlProfile) {
  const differences = [];

  const fieldComparisons = [
    { field: 'username', ignoreCase: true },
    { field: 'displayName', ignoreCase: false },
    { field: 'email', ignoreCase: true },
  ];

  for (const comparison of fieldComparisons) {
    const { field, ignoreCase } = comparison;
    const fsValue = firestoreProfile[field];
    const sqlValue = sqlProfile ? sqlProfile[field] : null;

    const normalizedFs = ignoreCase && typeof fsValue === 'string' ? fsValue.toLowerCase() : fsValue;
    const normalizedSql =
      ignoreCase && typeof sqlValue === 'string' ? sqlValue.toLowerCase() : sqlValue;

    if (normalizedFs === normalizedSql) {
      continue;
    }

    const fsPresented = fsValue === undefined ? null : fsValue;
    const sqlPresented = sqlValue === undefined ? null : sqlValue;

    differences.push({
      field,
      firestoreValue: fsPresented,
      sqlValue: sqlPresented,
    });
  }

  return differences;
}

async function fetchSqlProfiles(pool, authUids) {
  if (!Array.isArray(authUids) || authUids.length === 0) {
    return new Map();
  }

  const request = pool.request();
  const placeholders = [];

  authUids.forEach((uid, index) => {
    const paramName = `authUid${index}`;
    request.input(paramName, sql.NVarChar(64), uid);
    placeholders.push(`@${paramName}`);
  });

  const query = `
    SELECT Id, AuthUid, Email, Username, DisplayName, UpdatedAt
    FROM dbo.Users
    WHERE AuthUid IN (${placeholders.join(', ')})
  `;

  const result = await request.query(query);
  const records = Array.isArray(result?.recordset) ? result.recordset : [];
  const map = new Map();

  records.forEach((row) => {
    const profile = mapSqlProfile(row);
    if (profile?.authUid) {
      map.set(profile.authUid, profile);
    }
  });

  return map;
}

async function runProfileMirrorReconciliation() {
  const pool = await getPool();
  const aggregates = {
    totalProfiles: 0,
    sqlProfilesFetched: 0,
    sqlMatches: 0,
    missingSqlRows: 0,
    missingSqlIdField: 0,
    sqlIdMismatch: 0,
    fieldMismatchTotal: 0,
    fieldMismatchCounts: {},
  };

  const samples = {
    missingSqlRows: [],
    missingSqlIdField: [],
    sqlIdMismatch: [],
    fieldMismatches: [],
  };

  let lastDocumentId = null;
  let processed = 0;

  while (processed < MAX_DOCS) {
    const remaining = MAX_DOCS - processed;
    if (remaining <= 0) {
      break;
    }

    const limit = Math.min(BATCH_SIZE, remaining);
    let query = firestore.collection('users').orderBy(FieldPath.documentId()).limit(limit);
    if (lastDocumentId) {
      query = query.startAfter(lastDocumentId);
    }

    const snapshot = await query.get();

    if (snapshot.empty) {
      break;
    }

    const docs = snapshot.docs;
    processed += docs.length;

    const authUids = docs.map((doc) => doc.id);
    const sqlProfiles = await fetchSqlProfiles(pool, authUids);
    aggregates.sqlProfilesFetched += sqlProfiles.size;

    for (const doc of docs) {
      aggregates.totalProfiles += 1;
      const fsProfile = mapFirestoreProfile(doc);

      if (fsProfile.sqlUserId === null) {
        aggregates.missingSqlIdField += 1;
        if (samples.missingSqlIdField.length < SAMPLE_LIMIT) {
          samples.missingSqlIdField.push({ authUid: fsProfile.authUid });
        }
      }

      const sqlProfile = sqlProfiles.get(fsProfile.authUid);

      if (!sqlProfile) {
        aggregates.missingSqlRows += 1;
        if (samples.missingSqlRows.length < SAMPLE_LIMIT) {
          samples.missingSqlRows.push({ authUid: fsProfile.authUid });
        }
        continue;
      }

      if (fsProfile.sqlUserId !== null && sqlProfile.id !== null && sqlProfile.id !== fsProfile.sqlUserId) {
        aggregates.sqlIdMismatch += 1;
        if (samples.sqlIdMismatch.length < SAMPLE_LIMIT) {
          samples.sqlIdMismatch.push({
            authUid: fsProfile.authUid,
            firestoreSqlUserId: fsProfile.sqlUserId,
            sqlUserId: sqlProfile.id,
          });
        }
      }

      const differences = compareProfileRecords(fsProfile, sqlProfile);

      if (differences.length === 0) {
        aggregates.sqlMatches += 1;
      } else {
        differences.forEach((difference) => {
          aggregates.fieldMismatchTotal += 1;
          aggregates.fieldMismatchCounts[difference.field] =
            (aggregates.fieldMismatchCounts[difference.field] || 0) + 1;

          if (samples.fieldMismatches.length < SAMPLE_LIMIT) {
            samples.fieldMismatches.push({
              authUid: fsProfile.authUid,
              field: difference.field,
              firestoreValue: difference.firestoreValue,
              sqlValue: difference.sqlValue,
            });
          }
        });
      }
    }

    lastDocumentId = docs[docs.length - 1].id;
  }

  const result = {
    ...aggregates,
    samples,
    processed,
  };

  logStructured('INFO', 'profile_mirror.reconciliation_completed', {
    totalProfiles: aggregates.totalProfiles,
    sqlMatches: aggregates.sqlMatches,
    missingSqlRows: aggregates.missingSqlRows,
    missingSqlIdField: aggregates.missingSqlIdField,
    sqlIdMismatch: aggregates.sqlIdMismatch,
    fieldMismatchTotal: aggregates.fieldMismatchTotal,
  });

  if (
    aggregates.missingSqlRows > 0 ||
    aggregates.sqlIdMismatch > 0 ||
    aggregates.fieldMismatchTotal > 0 ||
    aggregates.missingSqlIdField > 0
  ) {
    const summaryLines = [];
    summaryLines.push(`Toplam incelenen profil: ${aggregates.totalProfiles}`);
    summaryLines.push(`Eksik SQL kaydı: ${aggregates.missingSqlRows}`);
    summaryLines.push(`sqlUserId uyuşmazlığı: ${aggregates.sqlIdMismatch}`);
    summaryLines.push(`Eksik sqlUserId alanı: ${aggregates.missingSqlIdField}`);
    summaryLines.push(`Alan uyumsuzluğu: ${aggregates.fieldMismatchTotal}`);

    const sampleDiffs = samples.fieldMismatches.slice(0, 5).map((item) => {
      const firestoreValue = item.firestoreValue === null || item.firestoreValue === undefined ? '∅' : item.firestoreValue;
      const sqlValue = item.sqlValue === null || item.sqlValue === undefined ? '∅' : item.sqlValue;
      return `${item.authUid} · ${item.field}: FS="${firestoreValue}" SQL="${sqlValue}"`;
    });

    if (sampleDiffs.length > 0) {
      summaryLines.push('Örnek alan farkları:');
      summaryLines.push(...sampleDiffs);
    }

    try {
      await sendSlackAlert(
        'WARNING',
        'Profile Mirror Reconciliation Uyarıları',
        summaryLines.join('\n'),
        {
          'Kontrol Edilen': aggregates.totalProfiles,
          'Eksik SQL': aggregates.missingSqlRows,
          'sqlUserId Uyuşmazlığı': aggregates.sqlIdMismatch,
          'Eksik sqlUserId': aggregates.missingSqlIdField,
          'Alan Farkları': aggregates.fieldMismatchTotal,
        },
      );
    } catch (error) {
      logStructured('ERROR', 'profile_mirror.reconciliation_alert_failed', {
        error: error.message,
      });
    }
  }

  return result;
}

const profileMirrorReconciliationJob = functions
  .region(DEFAULT_REGION)
  .pubsub.schedule(DEFAULT_SCHEDULE)
  .timeZone(DEFAULT_TIMEZONE)
  .onRun(async () => {
    try {
      const outcome = await runProfileMirrorReconciliation();
      console.log('Profile mirror reconciliation outcome:', outcome);
      return outcome;
    } catch (error) {
      console.error('Profile mirror reconciliation failed:', error);
      throw error;
    }
  });

module.exports = {
  runProfileMirrorReconciliation,
  profileMirrorReconciliationJob,
  compareProfileRecords,
  mapFirestoreProfile,
  mapSqlProfile,
};
