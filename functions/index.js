const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const { google } = require('googleapis');
const twilio = require('twilio');
const userSync = require('./user_sync');
const { PolicyEvaluator } = require('./rbac');
const { createSearchUsersHandler } = require('./search_users');
const { createFollowPreviewHandler } = require('./follow_preview');
const { createEnsureSqlUserHandler } = require('./ensure_user');
const { createCallableProcedure, listProcedureKeys } = require('./sql_gateway');
const realtimeMirror = require('./realtime_mirror');
const { createOnUserCreatedHandler, createOnUserDeletedHandler } = require('./user_sync_triggers');
const { dailyWalletConsistencyCheck } = require('./scheduled/wallet_consistency_check');
const { hourlyMetricsCollection } = require('./scheduled/metrics_collection');

admin.initializeApp();

const isFunctionsEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
const isHostedRuntime = Boolean(process.env.K_SERVICE || process.env.FUNCTION_TARGET);
const allowProdFlag = process.env.ALLOW_PROD === 'true';
// Jest loads this module directly during unit tests; treat that runtime as safe to bypass the
// hosted/emulator guard so tests can execute without requiring ALLOW_PROD.
const isUnitTestRuntime =
  process.env.NODE_ENV === 'test' || typeof process.env.JEST_WORKER_ID !== 'undefined';

if (!isFunctionsEmulator && !isHostedRuntime && !isUnitTestRuntime && !allowProdFlag) {
  throw new Error(
    'Prod kapalı: Emülatör dışında çalıştırma engellendi. ALLOW_PROD=true ile bilinçli olarak onaylayın.',
  );
}

const OTP_EXPIRY_MINUTES = 10;
const MAX_ATTEMPTS = 5;

const TRY_ON_CONSTANTS = Object.freeze({
  COLLECTION: 'try_on_sessions',
  STATUS_ACTIVE: 'ACTIVE',
  STATUS_EXPIRED: 'EXPIRED',
  STATUS_CANCELLED: 'CANCELLED',
  DEFAULT_DURATION_SEC: 30,
  DEFAULT_COOLDOWN_SEC: 3600,
  DEFAULT_MAX_DAILY_TRIES: 3,
  EXPIRY_SWEEP_BATCH: 200,
  EXPIRY_SWEEP_MAX_ITERATIONS: 6,
  DEFAULT_SIGNED_URL_TTL_SEC: 120,
  MAX_SIGNED_URL_TTL_SEC: 600,
});

const normalizeItemId = (value) => (value ?? '').toString().trim();

const parseBoolean = (value, defaultValue = false) => {
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
};

const ensureAuthenticatedContext = (context) => {
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Bu işlemi gerçekleştirmek için giriş yapmalısınız.',
    );
  }
  return context.auth.uid;
};

let policyEvaluatorInstance = null;

const getPolicyEvaluator = () => {
  if (!policyEvaluatorInstance) {
    try {
      policyEvaluatorInstance = PolicyEvaluator.fromEnv();
    } catch (error) {
      console.error('Policy evaluator initialization failed:', error);
      throw new functions.https.HttpsError(
        'failed-precondition',
        'RBAC policy evaluator cannot be initialized. Check RBAC_DATABASE_URL and database connectivity.',
      );
    }
  }
  return policyEvaluatorInstance;
};

const enforcePolicy = async (context, resource, action, scopeContext = {}) => {
  const uid = ensureAuthenticatedContext(context);
  const evaluator = getPolicyEvaluator();

  await evaluator.assertAllowed({
    uid,
    resource,
    action,
    scopeContext,
  });

  return uid;
};

const parsePositiveInt = (value, fallback, options = {}) => {
  const min = Number.isFinite(options.min) ? options.min : 1;
  const max = Number.isFinite(options.max) ? options.max : Number.POSITIVE_INFINITY;
  const num = Number(value);
  if (!Number.isFinite(num)) {
    return Math.min(Math.max(fallback, min), max);
  }
  const floored = Math.floor(num);
  if (floored < min) {
    return min;
  }
  if (floored > max) {
    return max;
  }
  return floored;
};

const toMillis = (timestamp) => {
  if (!timestamp) {
    return null;
  }
  if (typeof timestamp.toMillis === 'function') {
    return timestamp.toMillis();
  }
  if (typeof timestamp.toDate === 'function') {
    const date = timestamp.toDate();
    return date instanceof Date ? date.getTime() : null;
  }
  if (timestamp instanceof Date) {
    return timestamp.getTime();
  }
  return null;
};

const getOwnedItemsFromUserDoc = (data) => {
  if (!data || typeof data !== 'object') {
    return [];
  }
  const ownedPrimary = Array.isArray(data.ownedStoreItems) ? data.ownedStoreItems : [];
  const ownedLegacy = Array.isArray(data.ownedItems) ? data.ownedItems : [];
  return [...new Set([...ownedPrimary, ...ownedLegacy].map((item) => item?.toString?.().trim()).filter(Boolean))];
};

const normalizeEmail = (email) => email.trim().toLowerCase();

const normalizePhoneNumber = (phone) => (phone ?? '').toString().trim();

const isValidE164 = (phone) => /^\+[1-9]\d{7,14}$/.test(phone);

const generateOtpCode = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

const hashOtpKey = (identifier, code) => {
  const normalized = (identifier ?? '').toString().trim().toLowerCase();
  return crypto.createHash('sha256').update(`${normalized}|${code}`).digest('hex');
};

const shouldExposeDebugOtp = () => functions.config().environment?.expose_debug_otp === 'true';

exports.rbacCheckPermission = functions.https.onCall(async (data, context) => {
  const payload = data || {};
  const resource = payload.resource;
  const action = payload.action;

  if (!resource || !action) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'resource ve action alanları zorunludur.'
    );
  }

  const scopeContext = payload.scopeContext ?? {};
  const uid = await enforcePolicy(context, resource, action, scopeContext);

  return {
    ok: true,
    uid,
    resource,
    action,
  };
});

// ====================================================================
// REALTIME MIRROR TRIGGERS
// ====================================================================

exports.mirrorDmMessages = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onWrite(async (change, context) => {
    await realtimeMirror.handleDmMessageChange(change, context);
  });

exports.mirrorDmConversations = functions.firestore
  .document('conversations/{conversationId}')
  .onWrite(async (change, context) => {
    await realtimeMirror.handleDmConversationChange(change, context);
  });

exports.mirrorFollowEdges = functions.firestore
  .document('follows/{userId}/targets/{targetId}')
  .onWrite(async (change, context) => {
    await realtimeMirror.handleFollowEdgeChange(change, context);
  });

// Dakikalık cron tetikleyicisi ile Service Bus kuyruğunu boşaltarak SQL aynasını güncel tutar.
exports.drainRealtimeMirrorQueue = functions
  .runWith({ timeoutSeconds: 540, memory: '512MB' })
  .pubsub.schedule('every 1 minutes')
  .onRun(async () => {
    let drainer = null;

    try {
      const config = realtimeMirror.readRealtimeMirrorConfig();

      if (!config.featureFlags.writeMirrorEnabled) {
        functions.logger.info('realtimeMirror.drainer_skipped', {
          reason: 'write_mirror_disabled',
        });
        return null;
      }

      drainer = realtimeMirror.createRealtimeMirrorDrainer({ config });
      const stats = await drainer.drain();
      functions.logger.info('realtimeMirror.drainer_completed', stats);
      return stats;
    } catch (error) {
      functions.logger.error('realtimeMirror.drainer_error', {
        error: error?.message,
      });
      throw error;
    } finally {
      if (drainer) {
        await drainer.close();
      }
    }
  });

const validateOtpCode = (code) => {
  const normalized = (code ?? '').toString().trim();

  if (!/^[0-9]{6}$/.test(normalized)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Geçerli bir doğrulama kodu (6 haneli) gerekli.'
    );
  }

  return normalized;
};

const getTwilioClient = () => {
  const config = functions.config();
  const accountSid = config.twilio?.account_sid || process.env.TWILIO_ACCOUNT_SID;
  const authToken = config.twilio?.auth_token || process.env.TWILIO_AUTH_TOKEN;
  const fromNumber = config.twilio?.from_number || process.env.TWILIO_FROM_NUMBER;

  if (!accountSid || !authToken || !fromNumber) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'SMS gönderimi için Twilio yapılandırması gerekli.',
    );
  }

  return {
    client: twilio(accountSid, authToken),
    fromNumber,
  };
};

const getSmtpConfig = () => {
  const config = functions.config();
  const smtpHost = config.smtp?.host || process.env.SMTP_HOST;
  const smtpPortRaw = config.smtp?.port || process.env.SMTP_PORT;
  let smtpUser = config.smtp?.user || process.env.SMTP_USER;
  const smtpPassword =
    config.smtp?.password || process.env.SMTP_PASSWORD || process.env.SMTP_APP_PASSWORD;
  const fromEmail = config.smtp?.from_email || process.env.SMTP_FROM_EMAIL;
  const fromName = config.smtp?.from_name || process.env.SMTP_FROM_NAME || 'Cringe Bankası';

  if (!smtpUser && fromEmail) {
    smtpUser = fromEmail;
  }

  const smtpPort = smtpPortRaw ? Number(smtpPortRaw) : 587;

  const requireTls = parseBoolean(
    config.smtp?.require_tls ?? process.env.SMTP_REQUIRE_TLS,
    smtpPort !== 465,
  );

  const disableTlsVerification = parseBoolean(
    config.smtp?.disable_tls_verification ?? process.env.SMTP_DISABLE_TLS_VERIFICATION,
    false,
  );

  if (!smtpHost || !smtpUser || !smtpPassword || !fromEmail) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'SMTP ayarları eksik. host, user, password ve from_email gerekli.',
    );
  }

  return {
    smtpHost,
    smtpPort,
    smtpUser,
    smtpPassword,
    fromEmail,
    fromName,
    requireTls,
    disableTlsVerification,
  };
};

const mapSmtpErrorToHttpsError = (error) => {
  const errorCode = error?.code ?? null;
  const responseCode = error?.responseCode ?? null;
  const message = (error?.message ?? '').toString();
  const normalizedMessage = message.toLowerCase();
  const responseBodyMessage = error?.response?.body?.errors?.[0]?.message ?? null;

  const baseDetails = {
    errorCode,
    responseCode,
    command: error?.command ?? null,
    response: error?.response ?? null,
    message,
    providerMessage: responseBodyMessage,
  };

  const authCodes = new Set([530, 534, 535, 454, 432]);
  const connectionCodes = new Set([
    'ECONNECTION',
    'ETIMEDOUT',
    'ESOCKET',
    'ECONNREFUSED',
    'ENOTFOUND',
    'EAI_AGAIN',
    'ECONNRESET',
    'EPIPE',
    'ENETUNREACH',
    'EHOSTUNREACH',
  ]);

  if (
    errorCode === 'EAUTH' ||
    errorCode === 'EAUTHENTICATION' ||
    (typeof responseCode === 'number' && authCodes.has(responseCode)) ||
    normalizedMessage.includes('invalid login') ||
    normalizedMessage.includes('authentication failed')
  ) {
    return {
      code: 'failed-precondition',
      message:
        'SMTP kimlik bilgileri doğrulanamadı. Lütfen kullanıcı adı ve parola (veya uygulama şifresi) ayarlarını kontrol edin.',
      details: {
        ...baseDetails,
        reason: 'auth',
      },
      logContext: baseDetails,
    };
  }

  if (
    (typeof errorCode === 'string' && connectionCodes.has(errorCode)) ||
    normalizedMessage.includes('timed out') ||
    normalizedMessage.includes('connect') ||
    normalizedMessage.includes('socket') ||
    normalizedMessage.includes('hang up')
  ) {
    return {
      code: 'unavailable',
      message: 'SMTP sunucusuna bağlanılamadı. Sunucu adresini, portu ve ağ erişimini kontrol edin.',
      details: {
        ...baseDetails,
        reason: 'connection',
      },
      logContext: baseDetails,
    };
  }

  if (
    errorCode === 'EENVELOPE' ||
    normalizedMessage.includes('recipient address rejected') ||
    normalizedMessage.includes('invalid address')
  ) {
    return {
      code: 'invalid-argument',
      message: 'SMTP sunucusu e-posta adresini reddetti. Lütfen e-posta adresinin geçerli olduğundan emin olun.',
      details: {
        ...baseDetails,
        reason: 'envelope',
      },
      logContext: baseDetails,
    };
  }

  if (responseBodyMessage) {
    return {
      code: 'internal',
      message: responseBodyMessage,
      details: {
        ...baseDetails,
        reason: 'provider',
      },
      logContext: baseDetails,
    };
  }

  return {
    code: 'internal',
    message: 'Doğrulama e-postası gönderilemedi. Lütfen daha sonra tekrar deneyin.',
    details: {
      ...baseDetails,
      reason: 'unknown',
    },
    logContext: baseDetails,
  };
};

const sendOtpCore = async (rawEmail) => {
  const trimmedEmail = (rawEmail ?? '').toString().trim();

  if (!trimmedEmail) {
    throw new functions.https.HttpsError('invalid-argument', 'E-posta adresi gerekli.');
  }

  const normalizedEmail = normalizeEmail(trimmedEmail);
  const {
    smtpHost,
    smtpPort,
    smtpUser,
    smtpPassword,
    fromEmail,
    fromName,
    requireTls,
    disableTlsVerification,
  } = getSmtpConfig();

  const transporterOptions = {
    host: smtpHost,
    port: smtpPort,
    secure: smtpPort === 465,
    requireTLS: requireTls,
    auth: {
      user: smtpUser,
      pass: smtpPassword,
    },
  };

  if (disableTlsVerification) {
    transporterOptions.tls = {
      rejectUnauthorized: false,
    };
  }

  const transporter = nodemailer.createTransport(transporterOptions);

  const code = generateOtpCode();
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000)
  );

  const docRef = admin.firestore().collection('email_otps').doc(normalizedEmail);

  await docRef.set({
    email: normalizedEmail,
  hash: hashOtpKey(normalizedEmail, code),
    expiresAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastAttemptAt: null,
    attempts: 0,
  });

  const mailOptions = {
    to: trimmedEmail,
    from: {
      address: fromEmail,
      name: fromName,
    },
    subject: 'Cringe Bankası Doğrulama Kodun',
    text: `Merhaba! Cringe Bankası hesabını doğrulamak için kodun: ${code}. Kod ${OTP_EXPIRY_MINUTES} dakika boyunca geçerli.`,
    html: `
      <p>Merhaba!</p>
      <p><strong>Cringe Bankası</strong> hesabını doğrulamak için kullanman gereken kod:</p>
      <h2 style="font-size: 28px; letter-spacing: 4px;">${code}</h2>
      <p>Kod ${OTP_EXPIRY_MINUTES} dakika içinde geçerliliğini yitirir.</p>
      <p>Eğer bu isteği sen yapmadıysan lütfen görmezden gel.</p>
      <p>Keyifli cringe'lemeler! 🤭</p>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    functions.logger.info('OTP e-postası gönderildi', { email: normalizedEmail });
  } catch (error) {
    const logPayload = {
      email: normalizedEmail,
      error: error?.response?.body ?? error?.message ?? error,
      statusCode: error?.code ?? error?.response?.statusCode,
    };
    const mappedError = mapSmtpErrorToHttpsError(error);
    functions.logger.error('OTP e-postası gönderilemedi', {
      ...logPayload,
      errorCode: mappedError.details?.errorCode ?? null,
      responseCode: mappedError.details?.responseCode ?? null,
    });

    throw new functions.https.HttpsError(
      mappedError.code,
      mappedError.message,
      mappedError.details,
    );
  }

  return { code };
};

const verifyOtpCore = async (rawEmail, rawCode) => {
  const trimmedEmail = (rawEmail ?? '').toString().trim();

  if (!trimmedEmail) {
    throw new functions.https.HttpsError('invalid-argument', 'E-posta adresi gerekli.');
  }

  const normalizedEmail = normalizeEmail(trimmedEmail);
  const normalizedCode = validateOtpCode(rawCode);

  const docRef = admin.firestore().collection('email_otps').doc(normalizedEmail);
  const snapshot = await docRef.get();

  if (!snapshot.exists) {
    return { success: false, reason: 'not-found' };
  }

  const data = snapshot.data() || {};
  const attempts = Number.isFinite(data.attempts) ? data.attempts : 0;

  if (attempts >= MAX_ATTEMPTS) {
    await docRef.delete();
    return { success: false, reason: 'too-many-attempts' };
  }

  const expiresAt = data.expiresAt;
  const expiresDate = expiresAt?.toDate ? expiresAt.toDate() : null;
  if (!expiresDate || expiresDate.getTime() <= Date.now()) {
    await docRef.delete();
    return { success: false, reason: 'expired' };
  }

  const storedHash = data.hash;
  const expectedHash = hashOtpKey(normalizedEmail, normalizedCode);

  if (storedHash && storedHash === expectedHash) {
    await docRef.delete();
    return { success: true };
  }

  await docRef.update({
    attempts: admin.firestore.FieldValue.increment(1),
    lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const nextAttempts = attempts + 1;

  return {
    success: false,
    reason: 'invalid-code',
    remainingAttempts: Math.max(0, MAX_ATTEMPTS - nextAttempts),
    attempts: nextAttempts,
  };
};

const sendPhoneOtpCore = async (rawPhone, uid) => {
  const normalizedPhone = normalizePhoneNumber(rawPhone);

  if (!normalizedPhone) {
    throw new functions.https.HttpsError('invalid-argument', 'Telefon numarası gerekli.');
  }

  if (!isValidE164(normalizedPhone)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Telefon numarası E.164 formatında olmalı (örn. +905XXXXXXXXX).',
    );
  }

  const { client, fromNumber } = getTwilioClient();

  const code = generateOtpCode();
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000),
  );

  const docRef = admin.firestore().collection('phone_otps').doc(normalizedPhone);

  await docRef.set({
    phoneNumber: normalizedPhone,
    uid,
    hash: hashOtpKey(normalizedPhone, code),
    expiresAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastAttemptAt: null,
    attempts: 0,
  });

  try {
    await client.messages.create({
      from: fromNumber,
      to: normalizedPhone,
      body: `Cringe Bankası doğrulama kodun: ${code}. Kod ${OTP_EXPIRY_MINUTES} dakika geçerli.`,
    });
    functions.logger.info('OTP SMS gönderildi', { phone: normalizedPhone, uid });
  } catch (error) {
    functions.logger.error('OTP SMS gönderilemedi', {
      phone: normalizedPhone,
      error: error?.message ?? error,
    });
    throw new functions.https.HttpsError(
      'internal',
      'Doğrulama SMS\'i gönderilemedi.',
      error?.message ?? error,
    );
  }

  return { code };
};

const verifyPhoneOtpCore = async (rawPhone, rawCode) => {
  const normalizedPhone = normalizePhoneNumber(rawPhone);

  if (!normalizedPhone) {
    throw new functions.https.HttpsError('invalid-argument', 'Telefon numarası gerekli.');
  }

  const normalizedCode = validateOtpCode(rawCode);

  const docRef = admin.firestore().collection('phone_otps').doc(normalizedPhone);
  const snapshot = await docRef.get();

  if (!snapshot.exists) {
    return { success: false, reason: 'not-found' };
  }

  const data = snapshot.data() || {};
  const attempts = Number.isFinite(data.attempts) ? data.attempts : 0;

  if (attempts >= MAX_ATTEMPTS) {
    await docRef.delete();
    return { success: false, reason: 'too-many-attempts' };
  }

  const expiresAt = data.expiresAt;
  const expiresDate = expiresAt?.toDate ? expiresAt.toDate() : null;
  if (!expiresDate || expiresDate.getTime() <= Date.now()) {
    await docRef.delete();
    return { success: false, reason: 'expired' };
  }

  const storedHash = data.hash;
  const expectedHash = hashOtpKey(normalizedPhone, normalizedCode);

  if (storedHash && storedHash === expectedHash) {
    await docRef.delete();
    return { success: true, uid: data.uid ?? null };
  }

  await docRef.update({
    attempts: admin.firestore.FieldValue.increment(1),
    lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const nextAttempts = attempts + 1;

  return {
    success: false,
    reason: 'invalid-code',
    remainingAttempts: Math.max(0, MAX_ATTEMPTS - nextAttempts),
    attempts: nextAttempts,
  };
};

exports.sendEmailOtp = functions.region('europe-west1').https.onCall(async (data, context) => {
  const rawEmail = data && data.email ? data.email : '';
  const { code } = await sendOtpCore(rawEmail);

  const response = { success: true };
  if (shouldExposeDebugOtp()) {
    response.debugCode = code;
  }

  return response;
});

const extractEmailFromBody = (body) => {
  if (!body || typeof body !== 'object') {
    return '';
  }

  if (typeof body.email === 'string') {
    return body.email;
  }

  if (body.data && typeof body.data.email === 'string') {
    return body.data.email;
  }

  return '';
};

const mapHttpsErrorToStatus = (code) => {
  switch (code) {
    case 'invalid-argument':
      return 400;
    case 'failed-precondition':
      return 412;
    case 'already-exists':
      return 409;
    case 'permission-denied':
      return 403;
    default:
      return 500;
  }
};

exports.sendEmailOtpHttp = functions.region('europe-west1').https.onRequest(async (req, res) => {
  const origin = req.headers.origin ?? '*';
  res.set('Access-Control-Allow-Origin', origin);
  res.set('Vary', 'Origin');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, X-Firebase-AppCheck, X-Firebase-Client, X-Firebase-Functions-Client, X-Firebase-GMPID, X-Firebase-Installations-Auth'
  );
  res.set('Access-Control-Allow-Credentials', 'true');
  res.set('Access-Control-Max-Age', '3600');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({
      error: 'method-not-allowed',
      message: 'Bu uç noktaya yalnızca POST isteği yapılabilir.',
    });
    return;
  }

  let rawEmail = '';

  try {
    if (typeof req.body === 'string' && req.body) {
      rawEmail = extractEmailFromBody(JSON.parse(req.body));
    } else {
      rawEmail = extractEmailFromBody(req.body);
    }
  } catch (parseError) {
    functions.logger.error('İstek gövdesi çözümlenemedi', { error: parseError });
    res.status(400).json({
      error: 'invalid-json',
      message: 'Geçersiz JSON gövdesi.',
    });
    return;
  }

  if (!rawEmail) {
    res.status(400).json({
      error: 'invalid-argument',
      message: 'E-posta adresi gerekli.',
    });
    return;
  }

  try {
    const { code } = await sendOtpCore(rawEmail);
    const response = { success: true };
    if (shouldExposeDebugOtp()) {
      response.debugCode = code;
    }
    res.status(200).json(response);
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      res.status(mapHttpsErrorToStatus(error.code)).json({
        error: error.code,
        message: error.message,
        details: error.details ?? null,
      });
      return;
    }

    functions.logger.error('HTTP OTP isteği başarısız oldu', {
      error: error?.message ?? error,
    });

    res.status(500).json({
      error: 'internal',
      message: 'Doğrulama e-postası gönderilemedi.',
    });
  }
});

exports.verifyEmailOtp = functions.region('europe-west1').https.onCall(async (data, context) => {
  try {
    const rawEmail = data?.email ?? '';
    const rawCode = data?.code ?? '';
    return await verifyOtpCore(rawEmail, rawCode);
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    functions.logger.error('verifyEmailOtp failed', { error: error?.message ?? error });
    throw new functions.https.HttpsError(
      'internal',
      'Doğrulama işlemi tamamlanamadı.',
      error?.message ?? error
    );
  }
});

exports.confirmEmailUpdate = functions.region('europe-west1').https.onCall(async (data, context) => {
  const uid = ensureAuthenticatedContext(context);
  const rawEmail = data?.email ?? '';
  const rawCode = data?.code ?? '';

  const normalizedEmail = normalizeEmail(rawEmail);
  const verification = await verifyOtpCore(normalizedEmail, rawCode);

  if (!verification.success) {
    return verification;
  }

  try {
    const existing = await admin.auth().getUserByEmail(normalizedEmail);
    if (existing && existing.uid !== uid) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Bu e-posta adresi başka bir hesap tarafından kullanılıyor.',
      );
    }
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        'internal',
        'E-posta doğrulaması tamamlanamadı.',
        error?.message ?? error,
      );
    }
  }

  await admin.auth().updateUser(uid, {
    email: normalizedEmail,
    emailVerified: true,
  });

  await admin.firestore().collection('users').doc(uid).set(
    {
      email: normalizedEmail,
      emailVerified: true,
      email_lower: normalizedEmail,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { success: true };
});

exports.sendPhoneOtp = functions.region('europe-west1').https.onCall(async (data, context) => {
  const uid = ensureAuthenticatedContext(context);
  const rawPhone = data?.phoneNumber ?? '';

  const { code } = await sendPhoneOtpCore(rawPhone, uid);

  const response = { success: true };
  if (shouldExposeDebugOtp()) {
    response.debugCode = code;
  }
  return response;
});

exports.confirmPhoneUpdate = functions.region('europe-west1').https.onCall(async (data, context) => {
  const uid = ensureAuthenticatedContext(context);
  const rawPhone = data?.phoneNumber ?? '';
  const rawCode = data?.code ?? '';

  const normalizedPhone = normalizePhoneNumber(rawPhone);
  const verification = await verifyPhoneOtpCore(normalizedPhone, rawCode);

  if (!verification.success) {
    return verification;
  }

  if (verification.uid && verification.uid !== uid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Bu doğrulama kodu başka bir kullanıcı için oluşturuldu.',
    );
  }

  if (!isValidE164(normalizedPhone)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Telefon numarası E.164 formatında olmalı (örn. +905XXXXXXXXX).',
    );
  }

  try {
    const existing = await admin.auth().getUserByPhoneNumber(normalizedPhone);
    if (existing && existing.uid !== uid) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Bu telefon numarası başka bir hesapta kayıtlı.',
      );
    }
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        'internal',
        'Telefon doğrulaması tamamlanamadı.',
        error?.message ?? error,
      );
    }
  }

  await admin.auth().updateUser(uid, {
    phoneNumber: normalizedPhone,
  });

  await admin.firestore().collection('users').doc(uid).set(
    {
      phoneNumber: normalizedPhone,
      phoneNumberVerified: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { success: true };
});

const extractCodeFromBody = (body) => {
  if (!body || typeof body !== 'object') {
    return '';
  }

  if (typeof body.code === 'string') {
    return body.code;
  }

  if (body.data && typeof body.data.code === 'string') {
    return body.data.code;
  }

  return '';
};

exports.verifyEmailOtpHttp = functions.region('europe-west1').https.onRequest(async (req, res) => {
  const origin = req.headers.origin ?? '*';
  res.set('Access-Control-Allow-Origin', origin);
  res.set('Vary', 'Origin');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, X-Firebase-AppCheck, X-Firebase-Client, X-Firebase-Functions-Client, X-Firebase-GMPID, X-Firebase-Installations-Auth'
  );
  res.set('Access-Control-Allow-Credentials', 'true');
  res.set('Access-Control-Max-Age', '3600');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({
      error: 'method-not-allowed',
      message: 'Bu uç nokta yalnızca POST isteklerini kabul eder.',
    });
    return;
  }

  let rawEmail = '';
  let rawCode = '';

  try {
    if (typeof req.body === 'string' && req.body) {
      const parsed = JSON.parse(req.body);
      rawEmail = extractEmailFromBody(parsed);
      rawCode = extractCodeFromBody(parsed);
    } else {
      rawEmail = extractEmailFromBody(req.body);
      rawCode = extractCodeFromBody(req.body);
    }
  } catch (parseError) {
    functions.logger.error('Doğrulama isteği gövdesi çözümlenemedi', {
      error: parseError,
    });
    res.status(400).json({
      error: 'invalid-json',
      message: 'Geçersiz JSON gövdesi.',
    });
    return;
  }

  if (!rawEmail) {
    res.status(400).json({
      error: 'invalid-argument',
      message: 'E-posta adresi gerekli.',
    });
    return;
  }

  if (!rawCode) {
    res.status(400).json({
      error: 'invalid-argument',
      message: 'Doğrulama kodu gerekli.',
    });
    return;
  }

  try {
    const result = await verifyOtpCore(rawEmail, rawCode);
    res.status(200).json(result);
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      res.status(mapHttpsErrorToStatus(error.code)).json({
        error: error.code,
        message: error.message,
        details: error.details ?? null,
      });
      return;
    }

    functions.logger.error('HTTP OTP doğrulama isteği başarısız oldu', {
      error: error?.message ?? error,
    });

    res.status(500).json({
      error: 'internal',
      message: 'Doğrulama işlemi tamamlanamadı.',
    });
  }
});

// ---------------------------------------------------------------------------
// 💳 CringeCoin In-App Purchase Verification & Wallet Ledger Helpers
// ---------------------------------------------------------------------------

const IAP_CONSTANTS = Object.freeze({
  ANDROID_SCOPE: 'https://www.googleapis.com/auth/androidpublisher',
  ANDROID_PLATFORM: 'android',
  IOS_PLATFORM: 'ios',
  APPLE_PRODUCTION_URL: 'https://buy.itunes.apple.com/verifyReceipt',
  APPLE_SANDBOX_URL: 'https://sandbox.itunes.apple.com/verifyReceipt',
});

let androidPublisherClientPromise;

const getIapConfig = () => {
  const config = functions.config();
  return {
    androidPackageName:
      config.iap?.android_package ?? process.env.IAP_ANDROID_PACKAGE ?? '',
    appleSharedSecret:
      config.apple?.shared_secret ?? process.env.APPLE_SHARED_SECRET ?? '',
    androidServiceAccount: config.googleplay ?? undefined,
  };
};

const requiredString = (value, fieldName) => {
  const normalized = (value ?? '').toString().trim();
  if (!normalized) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${fieldName} değeri gerekli.`,
    );
  }
  return normalized;
};

const normalizePlatform = (value) => {
  const normalized = (value ?? '').toString().toLowerCase();
  if (normalized === IAP_CONSTANTS.ANDROID_PLATFORM) return IAP_CONSTANTS.ANDROID_PLATFORM;
  if (normalized === IAP_CONSTANTS.IOS_PLATFORM) return IAP_CONSTANTS.IOS_PLATFORM;
  throw new functions.https.HttpsError('invalid-argument', 'platform değeri android veya ios olmalı.');
};

const getAndroidPublisherClient = async () => {
  if (!androidPublisherClientPromise) {
    androidPublisherClientPromise = (async () => {
      const { androidServiceAccount } = getIapConfig();
      const auth = new google.auth.GoogleAuth({
        scopes: [IAP_CONSTANTS.ANDROID_SCOPE],
        credentials: androidServiceAccount,
      });
      const authClient = await auth.getClient();
      return google.androidpublisher({ version: 'v3', auth: authClient });
    })();
  }
  return androidPublisherClientPromise;
};

const verifyAndroidPurchase = async ({ packageName, sku, purchaseToken }) => {
  if (!packageName) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Android paket adı yapılandırılmamış. iap.android_package config değerini ayarlayın.',
    );
  }

  try {
    const publisher = await getAndroidPublisherClient();
    const { data } = await publisher.purchases.products.get({
      packageName,
      productId: sku,
      token: purchaseToken,
    });

    if (!data) {
      throw new Error('Google Play yanıtı boş döndü.');
    }

    if (data.purchaseState !== 0) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Satın alma tamamlanmamış görünüyor (purchaseState ≠ 0).',
      );
    }

    return {
      transactionId: data.orderId || purchaseToken,
      productId: data.productId || sku,
      acknowledgementState: data.acknowledgementState,
      purchaseTimeMillis: Number(data.purchaseTimeMillis ?? Date.now()),
      purchaseDateMillis: Number(data.purchaseTimeMillis ?? Date.now()),
      originalTransactionId: null,
    };
  } catch (error) {
    functions.logger.error('Android purchase verification failed', {
      error: error?.message ?? error,
    });
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Google Play doğrulaması başarısız oldu.',
      error?.message ?? error,
    );
  }
};

const callAppleVerifyEndpoint = async (endpoint, payload) => {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Apple doğrulama isteği başarısız oldu (${response.status}): ${text}`);
  }

  return response.json();
};

const verifyAppleReceipt = async ({ receiptData, productSku, sharedSecret, expectedTransactionId }) => {
  if (!sharedSecret) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Apple shared secret yapılandırılmadı. apple.shared_secret config değerini ayarlayın.',
    );
  }

  const payload = {
    'receipt-data': receiptData,
    password: sharedSecret,
    'exclude-old-transactions': true,
  };

  let result = await callAppleVerifyEndpoint(IAP_CONSTANTS.APPLE_PRODUCTION_URL, payload);
  if (result?.status === 21007) {
    result = await callAppleVerifyEndpoint(IAP_CONSTANTS.APPLE_SANDBOX_URL, payload);
  }

  if (result?.status !== 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Apple doğrulaması başarısız (status: ${result?.status ?? 'unknown'}).`,
    );
  }

  const receiptInApp = Array.isArray(result?.latest_receipt_info)
    ? result.latest_receipt_info
    : Array.isArray(result?.receipt?.in_app)
    ? result.receipt.in_app
    : [];

  if (!receiptInApp.length) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Apple doğrulaması başarıyla döndü ancak in_app kayıtları bulunamadı.',
    );
  }

  const match = receiptInApp.find((entry) => {
    if (expectedTransactionId && entry.transaction_id === expectedTransactionId) {
      return true;
    }
    return entry.product_id === productSku;
  }) || receiptInApp[0];

  if (!match) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Uygun bir Apple işlem kaydı bulunamadı.',
    );
  }

  return {
    transactionId: match.transaction_id || expectedTransactionId,
    productId: match.product_id || productSku,
    originalTransactionId: match.original_transaction_id,
    purchaseDateMillis: Number(match.purchase_date_ms ?? Date.now()),
  };
};

const createPurchaseDocumentId = (userId, transactionId) => {
  return crypto
    .createHash('sha1')
    .update(`${userId}|${transactionId}`)
    .digest('hex');
};

const ensureAuthenticatedUser = (context, expectedUserId) => {
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Bu işlemi gerçekleştirmek için giriş yapmalısınız.',
    );
  }
  if (context.auth.uid !== expectedUserId) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Yetkisiz kullanıcı işlemi.',
    );
  }
};

exports.verifyAndCreditIap = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    const userId = requiredString(data?.userId, 'userId');
    ensureAuthenticatedUser(context, userId);

    const platform = normalizePlatform(data?.platform);
    const productId = requiredString(data?.productId, 'productId');
    const storeSku = requiredString(data?.storeSku, 'storeSku');
    const tokenOrReceipt = requiredString(data?.tokenOrReceipt, 'tokenOrReceipt');
    const reportedPrice = data?.price != null ? Number(data.price) : null;
    const currency = data?.currency ? data.currency.toString() : null;

    const settings = getIapConfig();
    const db = admin.firestore();
    const productRef = db.collection('iap_products').doc(productId);
    const productSnap = await productRef.get();

    if (!productSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Ürün bulunamadı.');
    }

    const productData = productSnap.data() ?? {};
    if (productData.isActive === false) {
      throw new functions.https.HttpsError('failed-precondition', 'Ürün şu anda satışta değil.');
    }

    const expectedSku =
      platform === IAP_CONSTANTS.ANDROID_PLATFORM
        ? productData?.platforms?.android?.sku ?? productData?.androidSku
        : productData?.platforms?.ios?.sku ?? productData?.iosSku;

    if (expectedSku && expectedSku !== storeSku) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Gönderilen SKU ürünle eşleşmiyor.',
      );
    }

    const coinsAmount = Number(productData.coinsAmount ?? productData.coins ?? 0);
    if (!Number.isFinite(coinsAmount) || coinsAmount <= 0) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Ürün için geçerli bir coin miktarı yapılandırılmamış.',
      );
    }

    let verification;
    try {
      if (platform === IAP_CONSTANTS.ANDROID_PLATFORM) {
        verification = await verifyAndroidPurchase({
          packageName: settings.androidPackageName,
          sku: storeSku,
          purchaseToken: tokenOrReceipt,
        });
      } else {
        verification = await verifyAppleReceipt({
          receiptData: tokenOrReceipt,
          productSku: storeSku,
          sharedSecret: settings.appleSharedSecret,
          expectedTransactionId: data?.transactionId?.toString(),
        });
      }
    } catch (error) {
      const fallbackId = createPurchaseDocumentId(userId, `${platform}:${storeSku}:${tokenOrReceipt}`);
      await db.collection('purchases').doc(fallbackId).set(
        {
          userId,
          productId,
          storeSku,
          platform: platform.toUpperCase(),
          status: 'FAILED',
          errorMessage: error?.message ?? error,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      throw error instanceof functions.https.HttpsError
        ? error
        : new functions.https.HttpsError('failed-precondition', error?.message ?? error);
    }

    const transactionId = requiredString(
      verification.transactionId || data?.transactionId || tokenOrReceipt,
      'transactionId',
    );

    const purchaseDocId = createPurchaseDocumentId(userId, transactionId);
    const purchaseRef = db.collection('purchases').doc(purchaseDocId);
    const ledgerRef = db.collection('wallet_ledger').doc(purchaseDocId);
    const userRef = db.collection('users').doc(userId);

    const txnResult = await db.runTransaction(async (tx) => {
      const purchaseSnap = await tx.get(purchaseRef);
      if (purchaseSnap.exists) {
        const purchaseData = purchaseSnap.data() ?? {};
        if (purchaseData.status === 'SUCCESS') {
          const userSnap = await tx.get(userRef);
          const currentCoins = Number(userSnap.data()?.coins ?? purchaseData.finalBalance ?? 0);
          return {
            alreadyProcessed: true,
            totalCoins: currentCoins,
            amountCoins: Number(purchaseData.amountCoins ?? coinsAmount),
          };
        }
      }

      const ledgerSnap = await tx.get(ledgerRef);
      if (ledgerSnap.exists) {
        const ledgerData = ledgerSnap.data() ?? {};
        const userSnap = await tx.get(userRef);
        const currentCoins = Number(userSnap.data()?.coins ?? ledgerData.finalBalance ?? 0);
        return {
          alreadyProcessed: true,
          totalCoins: currentCoins,
          amountCoins: Number(ledgerData.coinsDelta ?? coinsAmount),
        };
      }

      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new functions.https.HttpsError('failed-precondition', 'Kullanıcı bulunamadı.');
      }

      const previousCoins = Number(userSnap.data()?.coins ?? 0);
      const updatedCoins = previousCoins + coinsAmount;
      const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();

      tx.set(
        purchaseRef,
        {
          userId,
          productId,
          storeSku,
          platform: platform.toUpperCase(),
          storeTransactionId: transactionId,
          amountCoins: coinsAmount,
          status: 'SUCCESS',
          price: reportedPrice,
          currency,
          verificationPayload: {
            productId: verification.productId,
            acknowledgementState: verification.acknowledgementState ?? null,
            originalTransactionId: verification.originalTransactionId ?? null,
            purchaseTimeMillis: verification.purchaseDateMillis ?? verification.purchaseTimeMillis ?? null,
          },
          createdAt: purchaseSnap.exists
            ? purchaseSnap.data()?.createdAt ?? serverTimestamp
            : serverTimestamp,
          updatedAt: serverTimestamp,
          finalBalance: updatedCoins,
        },
        { merge: true },
      );

      tx.set(ledgerRef, {
        userId,
        type: 'CREDIT_IAP',
        coinsDelta: coinsAmount,
        source: purchaseRef.id,
        idempotencyKey: transactionId,
        createdAt: serverTimestamp,
        finalBalance: updatedCoins,
      });

      tx.update(userRef, {
        coins: admin.firestore.FieldValue.increment(coinsAmount),
      });

      return {
        alreadyProcessed: false,
        totalCoins: updatedCoins,
        amountCoins: coinsAmount,
      };
    });

    return {
      success: true,
      platform,
      productId,
      storeSku,
      transactionId,
      amountCoins: txnResult.amountCoins,
      balance: txnResult.totalCoins,
      alreadyProcessed: txnResult.alreadyProcessed,
    };
  });

exports.iapRefundWebhook = functions
  .region('europe-west1')
  .https.onRequest(async (req, res) => {
    const origin = req.headers.origin ?? '*';
    res.set('Access-Control-Allow-Origin', origin);
    res.set('Vary', 'Origin');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Credentials', 'true');
    res.set('Access-Control-Max-Age', '3600');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({
        error: 'method-not-allowed',
        message: 'Bu uç nokta yalnızca POST isteklerini kabul eder.',
      });
      return;
    }

    const { transactionId, platform, reason } = req.body ?? {};
    const normalizedTransactionId = (transactionId ?? '').toString().trim();
    if (!normalizedTransactionId) {
      res.status(400).json({ error: 'invalid-argument', message: 'transactionId gerekli.' });
      return;
    }

    try {
      const db = admin.firestore();
      const purchaseSnap = await db
        .collection('purchases')
        .where('storeTransactionId', '==', normalizedTransactionId)
        .limit(1)
        .get();

      if (purchaseSnap.empty) {
        res.status(404).json({ error: 'not-found', message: 'İlgili satın alma kaydı bulunamadı.' });
        return;
      }

      const purchaseDoc = purchaseSnap.docs[0];
      const purchaseData = purchaseDoc.data() ?? {};
      const userId = purchaseData.userId;
      const refundCoins = Math.abs(Number(purchaseData.amountCoins ?? 0));
      if (!userId || refundCoins === 0) {
        res.status(200).json({ success: true, message: 'Kaydedilecek coin bulunamadı.' });
        return;
      }

      const ledgerRef = db.collection('wallet_ledger').doc(`${purchaseDoc.id}_refund`);
      const userRef = db.collection('users').doc(userId);

      await db.runTransaction(async (tx) => {
        const freshPurchase = await tx.get(purchaseDoc.ref);
        const currentStatus = freshPurchase.data()?.status;
        if (currentStatus === 'REFUNDED') {
          return;
        }

        const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
        tx.update(purchaseDoc.ref, {
          status: 'REFUNDED',
          refundReason: reason ?? null,
          updatedAt: serverTimestamp,
        });

        tx.set(ledgerRef, {
          userId,
          type: 'REFUND',
          coinsDelta: -refundCoins,
          source: purchaseDoc.id,
          idempotencyKey: `${normalizedTransactionId}:refund`,
          createdAt: serverTimestamp,
        }, { merge: true });

        tx.update(userRef, {
          coins: admin.firestore.FieldValue.increment(-refundCoins),
        });
      });

      exports.searchUsers = createSearchUsersHandler(admin);

      res.status(200).json({ success: true });
    } catch (error) {
      functions.logger.error('iapRefundWebhook failed', {
        error: error?.message ?? error,
        transactionId: normalizedTransactionId,
        platform,
      });
      res.status(500).json({
        error: 'internal',
        message: 'İade işlemi tamamlanamadı.',
        details: error?.message ?? error,
      });
    }
  });

const loadStoreItemForTryOn = async (itemId) => {
  const normalizedId = normalizeItemId(itemId);
  if (!normalizedId) {
    throw new functions.https.HttpsError('invalid-argument', 'itemId değeri gerekli.');
  }

  const doc = await admin.firestore().collection('store_items').doc(normalizedId).get();
  if (!doc.exists) {
    throw new functions.https.HttpsError('not-found', 'İlgili ürün mağazada bulunamadı.');
  }

  const data = doc.data() || {};
  return { id: doc.id, data };
};

const buildTryOnConfig = (rawConfig) => {
  const durationSec = parsePositiveInt(
    rawConfig?.durationSec,
    TRY_ON_CONSTANTS.DEFAULT_DURATION_SEC,
    { min: 5, max: 600 },
  );
  const cooldownSec = parsePositiveInt(
    rawConfig?.cooldownSec,
    TRY_ON_CONSTANTS.DEFAULT_COOLDOWN_SEC,
    { min: 30, max: 24 * 60 * 60 },
  );
  const maxDailyTries = parsePositiveInt(
    rawConfig?.maxDailyTries,
    TRY_ON_CONSTANTS.DEFAULT_MAX_DAILY_TRIES,
    { min: 1, max: 20 },
  );

  if (durationSec <= 0 || maxDailyTries <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Bu ürün için try-on özelliği devre dışı bırakılmış.',
      { reason: 'try-on-disabled' },
    );
  }

  return { durationSec, cooldownSec, maxDailyTries };
};

const buildSessionResponse = (sessionId, data, overrides = {}) => {
  const payload = { ...data, ...overrides };
  return {
    id: sessionId,
    userId: payload.userId,
    itemId: payload.itemId,
    status: payload.status,
    source: payload.source ?? 'store',
    startedAtMillis: toMillis(payload.startedAt),
    expiresAtMillis: toMillis(payload.expiresAt),
    durationSec: parsePositiveInt(
      payload.durationSec ?? payload.config?.durationSec,
      TRY_ON_CONSTANTS.DEFAULT_DURATION_SEC,
      { min: 5, max: 600 },
    ),
    cooldownSec: parsePositiveInt(
      payload.cooldownSec ?? payload.config?.cooldownSec,
      TRY_ON_CONSTANTS.DEFAULT_COOLDOWN_SEC,
      { min: 30, max: 24 * 60 * 60 },
    ),
    maxDailyTries: parsePositiveInt(
      payload.maxDailyTries ?? payload.config?.maxDailyTries,
      TRY_ON_CONSTANTS.DEFAULT_MAX_DAILY_TRIES,
      { min: 1, max: 20 },
    ),
  };
};

const sanitizeAssetPath = (value) => {
  const normalized = (value ?? '').toString().trim().replace(/\\/g, '/');
  if (!normalized) {
    return '';
  }
  const withoutLeading = normalized.replace(/^\/+/g, '');
  if (withoutLeading.includes('..')) {
    throw new functions.https.HttpsError('invalid-argument', 'Geçersiz dosya yolu.');
  }
  return withoutLeading;
};

exports.storeStartTryOnSession = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    const userId = ensureAuthenticatedContext(context);
    const itemId = normalizeItemId(data?.itemId);
    const source = normalizeItemId(data?.source) || 'store';

    if (!itemId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Try-on oturumu başlatmak için itemId değeri gerekli.',
      );
    }

    const db = admin.firestore();
    const nowTimestamp = admin.firestore.Timestamp.now();
    const nowMillisValue = toMillis(nowTimestamp) ?? Date.now();

    const { id: storeItemId, data: storeItemData } = await loadStoreItemForTryOn(itemId);
    const config = buildTryOnConfig(storeItemData.tryOn);

    const sessionsRef = db.collection(TRY_ON_CONSTANTS.COLLECTION);

    const activeSnapshot = await sessionsRef
      .where('userId', '==', userId)
      .where('itemId', '==', storeItemId)
      .where('status', '==', TRY_ON_CONSTANTS.STATUS_ACTIVE)
      .orderBy('expiresAt', 'desc')
      .limit(1)
      .get();

    if (!activeSnapshot.empty) {
      const activeDoc = activeSnapshot.docs[0];
      const activeData = activeDoc.data() || {};
      const activeExpiresMillis = toMillis(activeData.expiresAt);
      if (activeExpiresMillis && activeExpiresMillis > nowMillisValue) {
        const twentyFourHoursAgoReused = admin.firestore.Timestamp.fromMillis(
          nowMillisValue - 24 * 60 * 60 * 1000,
        );
        const recentQuotaSnapshot = await sessionsRef
          .where('userId', '==', userId)
          .where('itemId', '==', storeItemId)
          .where('startedAt', '>=', twentyFourHoursAgoReused)
          .orderBy('startedAt', 'desc')
          .limit(config.maxDailyTries)
          .get();

        return {
          success: true,
          session: buildSessionResponse(activeDoc.id, activeData),
          reusedSession: true,
          item: {
            id: storeItemId,
            name: storeItemData.name ?? null,
            preview: storeItemData.preview ?? null,
            full: storeItemData.full ?? null,
            tryOn: config,
          },
          limits: {
            cooldownRemainingSec: Math.max(0, Math.ceil((activeExpiresMillis - nowMillisValue) / 1000)),
            triesRemainingToday: Math.max(0, config.maxDailyTries - recentQuotaSnapshot.size),
          },
          serverTimeMillis: nowMillisValue,
        };
      }

      await activeDoc.ref.update({
        status: TRY_ON_CONSTANTS.STATUS_EXPIRED,
        expiredAt: nowTimestamp,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    const recentSnapshot = await sessionsRef
      .where('userId', '==', userId)
      .where('itemId', '==', storeItemId)
      .orderBy('startedAt', 'desc')
      .limit(1)
      .get();

    if (!recentSnapshot.empty) {
      const lastDoc = recentSnapshot.docs[0];
      const lastData = lastDoc.data() || {};
      const lastStartedMillis = toMillis(lastData.startedAt);
      if (lastStartedMillis) {
        const nextAllowedMillis = lastStartedMillis + config.cooldownSec * 1000;
        if (nextAllowedMillis > nowMillisValue) {
          const remainingSec = Math.ceil((nextAllowedMillis - nowMillisValue) / 1000);
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Try-on deneme hakkını yeniden kullanmadan önce beklemelisin.',
            {
              reason: 'cooldown-active',
              cooldownRemainingSec: remainingSec,
              nextAvailableAtMillis: nextAllowedMillis,
            },
          );
        }
      }
    }

    const twentyFourHoursAgo = admin.firestore.Timestamp.fromMillis(
      nowMillisValue - 24 * 60 * 60 * 1000,
    );

    const dayWindowSnapshot = await sessionsRef
      .where('userId', '==', userId)
      .where('itemId', '==', storeItemId)
      .where('startedAt', '>=', twentyFourHoursAgo)
      .orderBy('startedAt', 'desc')
      .limit(config.maxDailyTries)
      .get();

    if (dayWindowSnapshot.size >= config.maxDailyTries) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Bugün için try-on deneme hakkın tükendi.',
        {
          reason: 'daily-limit-reached',
          triesAllowedPerDay: config.maxDailyTries,
        },
      );
    }

    const expiresAt = admin.firestore.Timestamp.fromMillis(
      nowMillisValue + config.durationSec * 1000,
    );
    const sessionRef = sessionsRef.doc();
    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();

    const sessionPayload = {
      userId,
      itemId: storeItemId,
      status: TRY_ON_CONSTANTS.STATUS_ACTIVE,
      source,
      startedAt: nowTimestamp,
      expiresAt,
      durationSec: config.durationSec,
      cooldownSec: config.cooldownSec,
      maxDailyTries: config.maxDailyTries,
      createdAt: serverTimestamp,
      updatedAt: serverTimestamp,
    };

    await sessionRef.set(sessionPayload);

    return {
      success: true,
      session: buildSessionResponse(sessionRef.id, sessionPayload),
      item: {
        id: storeItemId,
        name: storeItemData.name ?? null,
        preview: storeItemData.preview ?? null,
        full: storeItemData.full ?? null,
        tryOn: config,
      },
      limits: {
        cooldownRemainingSec: config.cooldownSec,
        triesRemainingToday: Math.max(0, config.maxDailyTries - dayWindowSnapshot.size - 1),
      },
      serverTimeMillis: nowMillisValue,
    };
  });

exports.storeIssueFullAssetUrl = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    const userId = ensureAuthenticatedContext(context);
    const itemId = normalizeItemId(data?.itemId);
    const requestedPath = sanitizeAssetPath(data?.assetPath ?? data?.path);
    const ttlSec = parsePositiveInt(
      data?.expiresInSec,
      TRY_ON_CONSTANTS.DEFAULT_SIGNED_URL_TTL_SEC,
      { min: 30, max: TRY_ON_CONSTANTS.MAX_SIGNED_URL_TTL_SEC },
    );

    if (!itemId) {
      throw new functions.https.HttpsError('invalid-argument', 'itemId değeri gerekli.');
    }

    if (!requestedPath) {
      throw new functions.https.HttpsError('invalid-argument', 'assetPath değeri gerekli.');
    }

    const expectedPrefix = `store_items/${itemId}/full/`;
    if (!requestedPath.startsWith(expectedPrefix)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Bu dosya yolu için erişim iznin yok.',
        { reason: 'invalid-path' },
      );
    }

    const db = admin.firestore();
    const userSnap = await db.collection('users').doc(userId).get();
    if (!userSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Kullanıcı kaydı bulunamadı.');
    }

    const ownedItems = getOwnedItemsFromUserDoc(userSnap.data());
    let authorized = ownedItems.includes(itemId);
    const nowMillis = Date.now();

    if (!authorized) {
      const activeSessionSnapshot = await db
        .collection(TRY_ON_CONSTANTS.COLLECTION)
        .where('userId', '==', userId)
        .where('itemId', '==', itemId)
        .where('status', '==', TRY_ON_CONSTANTS.STATUS_ACTIVE)
        .orderBy('expiresAt', 'desc')
        .limit(1)
        .get();

      if (!activeSessionSnapshot.empty) {
        const sessionDoc = activeSessionSnapshot.docs[0];
        const sessionData = sessionDoc.data() || {};
        const expiresMillis = toMillis(sessionData.expiresAt);
        if (expiresMillis && expiresMillis > nowMillis) {
          authorized = true;
        } else {
          await sessionDoc.ref.update({
            status: TRY_ON_CONSTANTS.STATUS_EXPIRED,
            expiredAt: admin.firestore.Timestamp.now(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    }

    if (!authorized) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Bu içeriğe erişim için yeterli yetkin bulunmuyor.',
        { reason: 'unauthorized' },
      );
    }

    const expiryMillis = nowMillis + ttlSec * 1000;
    const bucket = admin.storage().bucket();
    const [signedUrl] = await bucket.file(requestedPath).getSignedUrl({
      version: 'v4',
      action: 'read',
      expires: expiryMillis,
    });

    return {
      success: true,
      url: signedUrl,
      expiresAtMillis: expiryMillis,
      ttlSec,
    };
  });

exports.tryOnSessionExpirySweep = functions
  .region('europe-west1')
  .pubsub.schedule('every 5 minutes')
  .onRun(async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const updatedAt = admin.firestore.FieldValue.serverTimestamp();
    let totalExpired = 0;

    for (let i = 0; i < TRY_ON_CONSTANTS.EXPIRY_SWEEP_MAX_ITERATIONS; i += 1) {
      const snapshot = await db
        .collection(TRY_ON_CONSTANTS.COLLECTION)
        .where('status', '==', TRY_ON_CONSTANTS.STATUS_ACTIVE)
        .where('expiresAt', '<=', now)
        .limit(TRY_ON_CONSTANTS.EXPIRY_SWEEP_BATCH)
        .get();

      if (snapshot.empty) {
        break;
      }

      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.update(doc.ref, {
          status: TRY_ON_CONSTANTS.STATUS_EXPIRED,
          expiredAt: now,
          updatedAt,
        });
      });

      await batch.commit();
      totalExpired += snapshot.size;

      if (snapshot.size < TRY_ON_CONSTANTS.EXPIRY_SWEEP_BATCH) {
        break;
      }
    }

    if (totalExpired > 0) {
      functions.logger.info('tryOnSessionExpirySweep completed', {
        totalExpired,
      });
    }

    return null;
  });

// ============================================================================
// ADMIN OPERATIONS - Import secure admin functions
// ============================================================================
const adminOps = require('./adminOps');
exports.assignCategoryAdmin = adminOps.assignCategoryAdmin;
exports.removeCategoryAdmin = adminOps.removeCategoryAdmin;
exports.toggleCategoryAdminStatus = adminOps.toggleCategoryAdminStatus;
exports.createCompetition = adminOps.createCompetition;
exports.updateCompetition = adminOps.updateCompetition;
exports.deleteCompetition = adminOps.deleteCompetition;

// One-time setup function (delete after use)
const setupAdmin = require('./setupAdmin');
exports.grantSuperAdminOnce = setupAdmin.grantSuperAdminOnce;

// Direct Messaging Functions (Legacy - Firestore only)
const messagingFunctions = require('./messaging_functions');
exports.createConversation = messagingFunctions.createConversation;
// exports.sendMessage = messagingFunctions.sendMessage; // Replaced by dmSendMessage (dual-write)
exports.editMessage = messagingFunctions.editMessage;
exports.deleteMessage = messagingFunctions.deleteMessage;
exports.setReadPointer = messagingFunctions.setReadPointer;

// Direct Messaging Functions (New - SQL + Firestore dual-write)
const dmFunctions = require('./dm/send_message');
const dmGetMessages = require('./dm/get_messages');
const dmMarkAsRead = require('./dm/mark_as_read');
const dmGetConversations = require('./dm/get_conversations');
exports.dmSendMessage = dmFunctions.sendMessage;
exports.dmGetMessages = dmGetMessages.getMessages;
exports.dmMarkAsRead = dmMarkAsRead.markAsRead;
exports.dmGetConversations = dmGetConversations.getConversations;

// Timeline Functions (SQL + Firestore dual-write)
const timelineCreateEvent = require('./timeline/create_event');
const timelineGetFeed = require('./timeline/get_feed');
const timelineMarkAsRead = require('./timeline/mark_as_read');
const timelineFollowUser = require('./timeline/follow_user');
exports.timelineCreateEvent = timelineCreateEvent.createEvent;
exports.timelineGetUserFeed = timelineGetFeed.getUserFeed;
exports.timelineMarkAsRead = timelineMarkAsRead.markAsRead;
exports.timelineFollowUser = timelineFollowUser.followUser;

// Analytics Functions (Scheduled Jobs + API Endpoints)
const analyticsJobs = require('./analytics/scheduled_jobs');
const analyticsApi = require('./analytics/get_analytics');
// Scheduled jobs
exports.aggregateUserDailyStats = analyticsJobs.aggregateUserDailyStats;
exports.updateEngagementScores = analyticsJobs.updateEngagementScores;
exports.detectTrendingContent = analyticsJobs.detectTrendingContent;
exports.collectSystemMetrics = analyticsJobs.collectSystemMetrics;
exports.refreshRecommendationCache = analyticsJobs.refreshRecommendationCache;
// API endpoints
exports.analyticsGetUserStats = analyticsApi.getUserStats;
exports.analyticsGetTrendingContent = analyticsApi.getTrendingContent;
exports.analyticsGetFollowRecommendations = analyticsApi.getFollowRecommendations;
exports.analyticsGetSystemAnalytics = analyticsApi.getSystemAnalytics;
exports.analyticsGetUserLeaderboard = analyticsApi.getUserLeaderboard;
exports.analyticsRefreshMyEngagementScore = analyticsApi.refreshMyEngagementScore;

// Cringe Store callable fonksiyonları
Object.assign(exports, require('./cringe_store_functions'));

// User synchronization & claims management
exports.syncUserClaimsOnUserWrite = userSync.syncUserClaimsOnUserWrite;
exports.refreshUserClaims = userSync.refreshUserClaims;

// ============================================================================
// USERNAME CHECK - Validate username availability
// ============================================================================
exports.usernameCheck = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    const username = (data?.username ?? '').toString().trim().toLowerCase();

    if (!username) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Kullanıcı adı gerekli.'
      );
    }

    // Basic validation rules (sync with client-side UsernamePolicies)
    const minLength = 3;
    const maxLength = 20;
    const validPattern = /^[a-z0-9._]+$/;

    const reasons = [];
    let isValid = true;

    if (username.length < minLength) {
      isValid = false;
      reasons.push(`Kullanıcı adı en az ${minLength} karakter olmalı.`);
    }

    if (username.length > maxLength) {
      isValid = false;
      reasons.push(`Kullanıcı adı en fazla ${maxLength} karakter olabilir.`);
    }

    if (!validPattern.test(username)) {
      isValid = false;
      reasons.push('Kullanıcı adı sadece küçük harf, rakam, nokta ve alt çizgi içerebilir.');
    }

    if (username.startsWith('.') || username.endsWith('.')) {
      isValid = false;
      reasons.push('Kullanıcı adı nokta ile başlayamaz veya bitemez.');
    }

    if (username.includes('..')) {
      isValid = false;
      reasons.push('Kullanıcı adında ardışık nokta kullanılamaz.');
    }

    // If format is invalid, return early
    if (!isValid) {
      return {
        valid: false,
        available: false,
        reasons,
      };
    }

    // Check availability in Firestore
    try {
      const usersRef = admin.firestore().collection('users');
      const snapshot = await usersRef
        .where('username', '==', username)
        .limit(1)
        .get();

      const isAvailable = snapshot.empty;

      // If authenticated user is checking their own current username, consider it available
      const currentUid = context.auth?.uid;
      if (currentUid && !snapshot.empty) {
        const doc = snapshot.docs[0];
        if (doc.id === currentUid) {
          return {
            valid: true,
            available: true,
            reasons: [],
          };
        }
      }

      if (!isAvailable) {
        reasons.push('Bu kullanıcı adı zaten kullanılıyor.');
      }

      return {
        valid: true,
        available: isAvailable,
        reasons,
      };
    } catch (error) {
      console.error('usernameCheck error:', error);
      throw new functions.https.HttpsError(
        'internal',
        'Kullanıcı adı kontrolü sırasında hata oluştu.'
      );
    }
  });

function registerSqlGatewayCallables(targetExports) {
  const hasOwn = Object.prototype.hasOwnProperty;
  const procedureKeys = listProcedureKeys().slice().sort();

  for (const key of procedureKeys) {
    if (typeof key !== 'string' || key.length === 0) {
      continue;
    }

    const suffix = key.charAt(0).toUpperCase() + key.slice(1);
    const exportName = `sqlGateway${suffix}`;

    if (hasOwn.call(targetExports, exportName)) {
      continue;
    }

    targetExports[exportName] = createCallableProcedure(key);
  }
}

exports.searchUsers = createSearchUsersHandler(admin);
exports.getFollowingPreview = createFollowPreviewHandler(admin);
exports.ensureSqlUser = createEnsureSqlUserHandler(admin);
exports.onUserCreated = createOnUserCreatedHandler();
exports.onUserDeleted = createOnUserDeletedHandler();
registerSqlGatewayCallables(exports);

// Scheduled Functions (Monitoring & Alerts)
exports.dailyWalletConsistencyCheck = dailyWalletConsistencyCheck;
exports.hourlyMetricsCollection = hourlyMetricsCollection;
