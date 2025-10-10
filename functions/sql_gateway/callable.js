const functions = require('firebase-functions');
const { PolicyEvaluator } = require('../rbac');
const { getPool } = require('./pool');
const { mapSqlErrorToHttps } = require('./errors');
const { getProcedure } = require('./procedures');

const APP_CHECK_BYPASS_ENABLED = process.env.SQL_GATEWAY_ALLOW_APP_CHECK_BYPASS === 'true';
const APP_CHECK_BYPASS_TOKEN = (process.env.SQL_GATEWAY_APP_CHECK_BYPASS_TOKEN || process.env.FIREBASE_APPCHECK_DEBUG_TOKEN || '').trim();
const IS_FUNCTIONS_EMULATOR = process.env.FUNCTIONS_EMULATOR === 'true';
const NODE_ENV = (process.env.NODE_ENV || '').toLowerCase();
const IS_PRODUCTION_ENV = NODE_ENV === 'production';

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

function getSqlDriverMetadata(error = {}) {
  const info = error.originalError?.info || error.info || {};
  const precedingInfo = Array.isArray(error.precedingErrors) && error.precedingErrors.length > 0
    ? error.precedingErrors[0]?.info
    : undefined;
  const mergedInfo = { ...info, ...precedingInfo };

  return compactObject({
    number: error.number ?? mergedInfo.number ?? null,
    state: error.state ?? mergedInfo.state ?? null,
    procedure: error.procName ?? mergedInfo.procName ?? mergedInfo.procedure ?? null,
    severity: mergedInfo.class ?? mergedInfo.severity ?? null,
    serverName: mergedInfo.serverName ?? null,
    lineNumber: mergedInfo.lineNumber ?? null,
  });
}

function extractGatewayReasonToken(message) {
  if (!message || typeof message !== 'string') {
    return null;
  }
  const match = message.match(/SQL_GATEWAY_[A-Z0-9_]+/);
  if (!match) {
    return null;
  }
  return match[0].replace('SQL_GATEWAY_', '').toLowerCase();
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
  if (normalized.includes('invalid') || normalized.includes('format') || normalized.includes('validation')) {
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

function assignSqlGatewayMeta(targetError, meta = {}) {
  if (!targetError || typeof targetError !== 'object') {
    return;
  }
  const existing = typeof targetError.sqlGatewayMeta === 'object' && targetError.sqlGatewayMeta !== null
    ? targetError.sqlGatewayMeta
    : {};
  targetError.sqlGatewayMeta = {
    ...existing,
    ...compactObject(meta),
  };
}

function buildHttpsErrorForReason(reason, { key, metadata, classification }) {
  const { code, message } = deriveHttpsInfoFromReason(reason);
  const details = compactObject({
    reason,
    classification,
    key,
    sql: metadata && Object.keys(metadata).length > 0 ? metadata : undefined,
  });
  return new functions.https.HttpsError(code, message, details);
}

function normalizeSqlGatewayError(error, definition, key) {
  const metadata = getSqlDriverMetadata(error);

  if (error instanceof functions.https.HttpsError) {
    assignSqlGatewayMeta(error, {
      classification: 'https-error',
      reason: typeof error.details === 'object' && error.details?.reason ? error.details.reason : error.message,
      key,
      sql: metadata,
    });
    return {
      error,
      classification: 'https-error',
      reason: error.sqlGatewayMeta?.reason || 'sql_gateway_failure',
      metadata,
      rawMessage: error.message,
    };
  }

  if (typeof definition?.mapError === 'function') {
    try {
      const mapped = definition.mapError(error, { key, metadata });
      if (mapped instanceof functions.https.HttpsError) {
        assignSqlGatewayMeta(mapped, {
          classification: 'definition-map',
          reason:
            (typeof mapped.details === 'object' && mapped.details?.reason) || mapped.message || 'definition_error',
          key,
          sql: metadata,
        });
        return {
          error: mapped,
          classification: 'definition-map',
          reason: mapped.sqlGatewayMeta?.reason || 'definition_error',
          metadata,
          rawMessage: error?.message,
        };
      }
    } catch (mapError) {
      functions.logger.error('sqlGateway.definition_map_failed', {
        key,
        error: mapError?.message,
      });
    }
  }

  const reasonToken =
    extractGatewayReasonToken(error?.originalError?.info?.message) ||
    extractGatewayReasonToken(error?.originalError?.message) ||
    extractGatewayReasonToken(error?.message);

  if (reasonToken) {
    const mapped = buildHttpsErrorForReason(reasonToken, {
      key,
      metadata,
      classification: 'gateway-reason',
    });
    assignSqlGatewayMeta(mapped, {
      classification: 'gateway-reason',
      reason: reasonToken,
      key,
      sql: metadata,
    });
    return {
      error: mapped,
      classification: 'gateway-reason',
      reason: reasonToken,
      metadata,
      rawMessage: error?.message,
    };
  }

  const number = metadata.number;
  if (number === 2601 || number === 2627) {
    const reason = 'unique_constraint_violation';
    const mapped = new functions.https.HttpsError('already-exists', reason, compactObject({
      reason,
      classification: 'constraint',
      key,
      sql: metadata,
    }));
    assignSqlGatewayMeta(mapped, {
      classification: 'constraint',
      reason,
      key,
      sql: metadata,
    });
    return {
      error: mapped,
      classification: 'constraint',
      reason,
      metadata,
      rawMessage: error?.message,
    };
  }

  if (number === 547) {
    const reason = 'constraint_violation';
    const mapped = new functions.https.HttpsError('failed-precondition', reason, compactObject({
      reason,
      classification: 'constraint',
      key,
      sql: metadata,
    }));
    assignSqlGatewayMeta(mapped, {
      classification: 'constraint',
      reason,
      key,
      sql: metadata,
    });
    return {
      error: mapped,
      classification: 'constraint',
      reason,
      metadata,
      rawMessage: error?.message,
    };
  }

  if (error?.code === 'ETIMEOUT') {
    const reason = 'sql_timeout';
    const mapped = new functions.https.HttpsError('deadline-exceeded', reason, compactObject({
      reason,
      classification: 'timeout',
      key,
      sql: metadata,
    }));
    assignSqlGatewayMeta(mapped, {
      classification: 'timeout',
      reason,
      key,
      sql: metadata,
    });
    return {
      error: mapped,
      classification: 'timeout',
      reason,
      metadata,
      rawMessage: error?.message,
    };
  }

  if (error?.code === 'ELOGIN') {
    const reason = 'sql_login_failed';
    const mapped = new functions.https.HttpsError('failed-precondition', reason, compactObject({
      reason,
      classification: 'connection',
      key,
      sql: metadata,
    }));
    assignSqlGatewayMeta(mapped, {
      classification: 'connection',
      reason,
      key,
      sql: metadata,
    });
    return {
      error: mapped,
      classification: 'connection',
      reason,
      metadata,
      rawMessage: error?.message,
    };
  }

  assignSqlGatewayMeta(error, {
    classification: 'unmapped',
    reason: 'sql_gateway_failure',
    key,
    sql: metadata,
  });

  return {
    error,
    classification: 'unmapped',
    reason: 'sql_gateway_failure',
    metadata,
    rawMessage: error?.message,
  };
}

function shouldAllowAppCheckBypass() {
  if (IS_FUNCTIONS_EMULATOR) {
    return true;
  }
  if (!APP_CHECK_BYPASS_ENABLED) {
    return false;
  }
  if (IS_PRODUCTION_ENV) {
    return false;
  }
  return true;
}

function hasBypassToken(context) {
  if (!APP_CHECK_BYPASS_TOKEN) {
    return true;
  }

  const headers = context?.rawRequest?.headers;
  if (!headers) {
    return false;
  }

  const candidate =
    headers['x-firebase-appcheck'] ||
    headers['x-app-check-bypass'] ||
    headers['x-app-check-debug'] ||
    headers['x-appcheck-debug'];

  if (!candidate || typeof candidate !== 'string') {
    return false;
  }

  return candidate.trim() === APP_CHECK_BYPASS_TOKEN;
}

function verifyAppCheck(definition, context, key) {
  if (definition.requireAppCheck === false) {
    return { status: 'skipped' };
  }

  if (context.app) {
    return { status: 'verified' };
  }

  if (shouldAllowAppCheckBypass() && hasBypassToken(context)) {
    functions.logger.warn('sqlGateway.app_check_bypass', {
      key,
      uid: context.auth?.uid ?? null,
      sourceIp: context.rawRequest?.ip ?? null,
    });
    return { status: 'bypass' };
  }

  functions.logger.warn('sqlGateway.app_check_missing', {
    key,
    uid: context.auth?.uid ?? null,
    allowBypass: shouldAllowAppCheckBypass(),
    hasBypassToken: Boolean(APP_CHECK_BYPASS_TOKEN),
  });

  throw new functions.https.HttpsError('failed-precondition', 'app_check_required');
}

let policyEvaluatorInstance = null;

function getPolicyEvaluator() {
  if (!policyEvaluatorInstance) {
    policyEvaluatorInstance = PolicyEvaluator.fromEnv();
  }
  return policyEvaluatorInstance;
}

async function enforcePolicy(context, definition, scopeContext, key) {
  if (!definition.access) {
    return;
  }

  const uid = context.auth?.uid;
  if (!uid) {
    functions.logger.warn('sqlGateway.policy.missing_auth', {
      key: key || null,
      resource: definition.access.resource,
      action: definition.access.action,
    });
    throw new functions.https.HttpsError('unauthenticated', 'authentication_required');
  }

  const evaluator = getPolicyEvaluator();
  const startedAt = Date.now();
  const scopeKeys = scopeContext && typeof scopeContext === 'object' ? Object.keys(scopeContext).slice(0, 5) : [];

  try {
    await evaluator.assertAllowed({
      uid,
      resource: definition.access.resource,
      action: definition.access.action,
      scopeContext: scopeContext || {},
    });

    const successLog = {
      key: key || null,
      resource: definition.access.resource,
      action: definition.access.action,
      uid,
      elapsedMs: Date.now() - startedAt,
      scopeKeys,
    };

    if (typeof functions.logger?.debug === 'function') {
      functions.logger.debug('sqlGateway.policy.allowed', successLog);
    }
  } catch (error) {
    const elapsedMs = Date.now() - startedAt;
    functions.logger.warn('sqlGateway.policy.denied', {
      key: key || null,
      resource: definition.access.resource,
      action: definition.access.action,
      uid,
      elapsedMs,
      scopeKeys,
      error: error?.message,
    });

    if (error instanceof functions.https.HttpsError) {
      throw new functions.https.HttpsError('permission-denied', 'policy_denied');
    }

    throw new functions.https.HttpsError('internal', 'policy_evaluation_failed');
  }
}

async function executeDefinition(definition, key, payload, context = {}) {
  const startedAt = Date.now();
  const appCheckStatus = context.__sqlGatewayAppCheck?.status || (context.app ? 'verified' : 'missing');
  const baseLogContext = {
    key,
    uid: context.auth?.uid ?? null,
    region: definition.region ?? null,
    resource: definition.access?.resource ?? null,
    action: definition.access?.action ?? null,
    payloadKeys:
      payload && typeof payload === 'object' && !Array.isArray(payload)
        ? Object.keys(payload).slice(0, 25)
        : [],
    appCheckStatus,
  };

  functions.logger.info('sqlGateway.attempt', baseLogContext);

  try {
    const pool = await getPool();
    const request = pool.request();
    if (typeof definition.bind === 'function') {
      definition.bind(request, payload, context);
    }

    const result = await (definition.execute
      ? definition.execute(request, payload, context)
      : request.execute(key));
    const transformed = definition.transform ? definition.transform(result, payload, context) : result;
    const elapsedMs = Date.now() - startedAt;
    const rowCount = Array.isArray(result?.recordset) ? result.recordset.length : undefined;

    const successLog = {
      ...baseLogContext,
      elapsedMs,
      rowCount,
      returnValue: result?.returnValue ?? null,
      outputKeys: result?.output ? Object.keys(result.output) : [],
    };

    if (typeof definition.logContextBuilder === 'function') {
      try {
        Object.assign(successLog, definition.logContextBuilder(result, payload, context) || {});
      } catch (logError) {
        functions.logger.warn('sqlGateway.log_context_failed', {
          key,
          error: logError?.message,
        });
      }
    }

    functions.logger.info('sqlGateway.success', successLog);

    return transformed;
  } catch (error) {
    const elapsedMs = Date.now() - startedAt;
    const normalized = normalizeSqlGatewayError(error, definition, key);
    const failureLog = {
      ...baseLogContext,
      elapsedMs,
      classification: normalized.classification,
      reason: normalized.reason,
      sqlNumber: normalized.metadata.number ?? null,
      sqlState: normalized.metadata.state ?? null,
      sqlProcedure: normalized.metadata.procedure ?? null,
      sqlSeverity: normalized.metadata.severity ?? null,
      rawError: normalized.rawMessage ?? error?.message ?? null,
      driverCode: error?.code ?? null,
    };

    functions.logger.error('sqlGateway.failure', failureLog);
    throw normalized.error;
  }
}

async function executeProcedure(key, payload, context = {}) {
  const definition = getProcedure(key);

  if (!definition) {
    throw new Error(`Unknown SQL gateway procedure: ${key}`);
  }

  try {
    return await executeDefinition(definition, key, payload, context);
  } catch (error) {
    throw mapSqlErrorToHttps(error);
  }
}

function createCallableProcedure(key, options = {}) {
  const definition = getProcedure(key);

  if (!definition) {
    throw new Error(`Unknown SQL gateway procedure: ${key}`);
  }

  const region = options.region || definition.region || 'europe-west1';

  return functions.region(region).https.onCall(async (data, context) => {
    const appCheckStatus = verifyAppCheck(definition, context, key);
    context.__sqlGatewayAppCheck = appCheckStatus;

    try {
      const payload = definition.parseInput ? definition.parseInput(data, context) : data || {};

      await enforcePolicy(
        context,
        definition,
        definition.scopeContextBuilder?.(data, context, payload),
        key
      );

      const result = await executeProcedure(key, payload, context);

      return {
        ok: true,
        data: result,
      };
    } catch (error) {
      throw error instanceof functions.https.HttpsError ? error : mapSqlErrorToHttps(error);
    }
  });
}

module.exports = {
  createCallableProcedure,
  executeProcedure,
};
