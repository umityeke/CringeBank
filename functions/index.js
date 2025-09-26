const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const crypto = require('crypto');

admin.initializeApp();

const OTP_EXPIRY_MINUTES = 10;
const MAX_ATTEMPTS = 5;

const normalizeEmail = (email) => email.trim().toLowerCase();

const generateOtpCode = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

const hashCode = (email, code) => {
  return crypto.createHash('sha256').update(`${normalizeEmail(email)}|${code}`).digest('hex');
};

const shouldExposeDebugOtp = () => functions.config().environment?.expose_debug_otp === 'true';

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

const getSmtpConfig = () => {
  const config = functions.config();
  const smtpHost = config.smtp?.host || process.env.SMTP_HOST;
  const smtpPortRaw = config.smtp?.port || process.env.SMTP_PORT;
  const smtpUser = config.smtp?.user || process.env.SMTP_USER;
  const smtpPassword = config.smtp?.password || process.env.SMTP_PASSWORD;
  const fromEmail = config.smtp?.from_email || process.env.SMTP_FROM_EMAIL;
  const fromName = config.smtp?.from_name || process.env.SMTP_FROM_NAME || 'Cringe Bankası';

  const smtpPort = smtpPortRaw ? Number(smtpPortRaw) : 587;

  if (!smtpHost || !smtpUser || !smtpPassword || !fromEmail) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'SMTP ayarları eksik. host, user, password ve from_email gerekli.'
    );
  }

  return {
    smtpHost,
    smtpPort,
    smtpUser,
    smtpPassword,
    fromEmail,
    fromName,
  };
};

const sendOtpCore = async (rawEmail) => {
  const trimmedEmail = (rawEmail ?? '').toString().trim();

  if (!trimmedEmail) {
    throw new functions.https.HttpsError('invalid-argument', 'E-posta adresi gerekli.');
  }

  const normalizedEmail = normalizeEmail(trimmedEmail);
  const { smtpHost, smtpPort, smtpUser, smtpPassword, fromEmail, fromName } = getSmtpConfig();

  const transporter = nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: smtpPort === 465,
    auth: {
      user: smtpUser,
      pass: smtpPassword,
    },
  });

  const code = generateOtpCode();
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000)
  );

  const docRef = admin.firestore().collection('email_otps').doc(normalizedEmail);

  await docRef.set({
    email: normalizedEmail,
    hash: hashCode(normalizedEmail, code),
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
    functions.logger.error('OTP e-postası gönderilemedi', logPayload);

    const detailsMessage = error?.response?.body?.errors?.[0]?.message ?? error?.message;
    throw new functions.https.HttpsError(
      'internal',
      'Doğrulama e-postası gönderilemedi.',
      detailsMessage,
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
  const expectedHash = hashCode(normalizedEmail, normalizedCode);

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
      message: 'Bu uç noktaya yalnızca POST isteği yapılabilir.',
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
