const functions = require('firebase-functions');

function compactObject(target = {}) {
  const result = {};
  for (const [key, value] of Object.entries(target)) {
    if (value === undefined || value === null) {
      continue;
    }
    if (typeof value === 'string' && value.length === 0) {
      continue;
    }
    result[key] = value;
  }
  return result;
}

function deriveHttpsInfoFromReason(reason) {
  if (!reason) {
    return { code: 'internal', message: 'sql_gateway_failure' };
  }

  const normalized = reason.toLowerCase();

  if (normalized.includes('not_found')) {
    return { code: 'not-found', message: reason };
  }
  if (normalized.includes('unauth')) {
    return { code: 'unauthenticated', message: reason };
  }
  if (normalized.includes('permission') || normalized.includes('forbidden')) {
    return { code: 'permission-denied', message: reason };
  }
  if (normalized.includes('invalid') || normalized.includes('validation') || normalized.includes('format')) {
    return { code: 'invalid-argument', message: reason };
  }
  if (normalized.includes('already') || normalized.includes('duplicate') || normalized.includes('exists')) {
    return { code: 'already-exists', message: reason };
  }
  if (
    normalized.includes('insufficient') ||
    normalized.includes('constraint') ||
    normalized.includes('failed') ||
    normalized.includes('locked')
  ) {
    return { code: 'failed-precondition', message: reason };
  }
  if (normalized.includes('timeout')) {
    return { code: 'deadline-exceeded', message: reason };
  }

  return { code: 'internal', message: reason };
}

function getSqlErrorNumber(error) {
  if (typeof error?.number === 'number') {
    return error.number;
  }
  if (typeof error?.sqlGatewayMeta?.sql?.number === 'number') {
    return error.sqlGatewayMeta.sql.number;
  }
  const info = error?.originalError?.info;
  if (typeof info?.number === 'number') {
    return info.number;
  }
  const preceding = Array.isArray(error?.precedingErrors) ? error.precedingErrors : [];
  for (const precedingError of preceding) {
    if (typeof precedingError?.info?.number === 'number') {
      return precedingError.info.number;
    }
  }
  return null;
}

function createHttpsErrorFromReason(reason, classification, key, sqlMetadata) {
  const { code, message } = deriveHttpsInfoFromReason(reason);
  return new functions.https.HttpsError(
    code,
    message,
    compactObject({
      reason,
      classification,
      key,
      sql: sqlMetadata,
    })
  );
}

function mapSqlErrorToHttps(error) {
  if (error instanceof functions.https.HttpsError) {
    return error;
  }

  const gatewayMeta = error?.sqlGatewayMeta;
  if (gatewayMeta?.reason) {
    return createHttpsErrorFromReason(
      gatewayMeta.reason,
      gatewayMeta.classification,
      gatewayMeta.key,
      gatewayMeta.sql
    );
  }

  const code = error?.code;

  if (code === 'ELOGIN') {
    return new functions.https.HttpsError('failed-precondition', 'sql_login_failed');
  }

  if (code === 'ETIMEOUT') {
    return new functions.https.HttpsError('deadline-exceeded', 'sql_timeout');
  }

  if (code === 'EALREADYCONNECTED') {
    return new functions.https.HttpsError('failed-precondition', 'sql_connection_state_invalid');
  }

  const number = getSqlErrorNumber(error);

  if (number === 2601 || number === 2627) {
    return new functions.https.HttpsError('already-exists', 'sql_unique_constraint_violation');
  }

  if (number === 547) {
    return new functions.https.HttpsError('failed-precondition', 'sql_constraint_violation');
  }

  if (error?.message === 'SQL_GATEWAY_NO_RESULT') {
    return new functions.https.HttpsError('internal', 'sql_no_result_returned');
  }

  if (error?.message === 'SQL_GATEWAY_INVALID_INPUT') {
    return new functions.https.HttpsError('invalid-argument', 'sql_invalid_input');
  }

  return new functions.https.HttpsError('internal', 'sql_gateway_failure');
}

module.exports = {
  mapSqlErrorToHttps,
};
