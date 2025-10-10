const functions = require('firebase-functions');
const { executeProcedure } = require('./sql_gateway');

const REGION = process.env.ENSURE_SQL_USER_REGION || 'europe-west1';
const CHAR_REPLACEMENTS = {
  'ğ': 'g',
  'Ğ': 'g',
  'ü': 'u',
  'Ü': 'u',
  'ş': 's',
  'Ş': 's',
  'ı': 'i',
  'I': 'i',
  'İ': 'i',
  'i': 'i',
  'ö': 'o',
  'Ö': 'o',
  'ç': 'c',
  'Ç': 'c',
  'á': 'a',
  'Á': 'a',
  'í': 'i',
  'Í': 'i',
  'ú': 'u',
  'Ú': 'u',
  'à': 'a',
  'À': 'a',
  'â': 'a',
  'Â': 'a',
  'ä': 'a',
  'Ä': 'a',
  'å': 'a',
  'è': 'e',
  'È': 'e',
  'é': 'e',
  'É': 'e',
  'ê': 'e',
  'Ê': 'e',
  'ë': 'e',
  'Ë': 'e',
  'ò': 'o',
  'Ò': 'o',
  'ó': 'o',
  'Ó': 'o',
  'ô': 'o',
  'Ô': 'o',
  'õ': 'o',
  'Õ': 'o',
  'ù': 'u',
  'Ù': 'u',
  'û': 'u',
  'Û': 'u',
  'ý': 'y',
  'Ý': 'y',
  'ÿ': 'y',
};

function toTurkishLowercase(value) {
  if (!value) {
    return '';
  }
  let result = '';
  for (let i = 0; i < value.length; i += 1) {
    const char = value[i];
    if (char === 'I') {
      result += 'ı';
    } else if (char === 'İ') {
      result += 'i';
    } else {
      result += char.toLowerCase();
    }
  }
  return result;
}

function foldToAscii(value) {
  if (!value) {
    return '';
  }
  let result = '';
  for (let i = 0; i < value.length; i += 1) {
    const char = value[i];
    result += CHAR_REPLACEMENTS[char] ?? char;
  }
  return result;
}

function sanitize(value) {
  if (!value) {
    return '';
  }
  return value.replace(/[^a-z0-9@._\s-]/gi, ' ').replace(/\s+/g, ' ').trim();
}

function buildNormalization(input) {
  if (!input) {
    return { normalizedTr: '', ascii: '' };
  }
  const lowered = toTurkishLowercase(input.toString().trim());
  const normalizedTr = sanitize(lowered);
  const ascii = sanitize(foldToAscii(lowered));
  return { normalizedTr, ascii };
}

function normalizeUsername(username) {
  const normalized = buildNormalization(username).ascii;
  return normalized.replace(/[@\s]+/g, '');
}

function normalizeFullName(fullName) {
  return buildNormalization(fullName).ascii;
}

function normalizeEmail(email) {
  return (email ?? '').toString().trim().toLowerCase();
}

function generateSearchKeywords({ fullName, username, email }) {
  const keywords = new Set();
  const normalizedFullName = normalizeFullName(fullName);
  if (normalizedFullName) {
    keywords.add(normalizedFullName);
    const tokens = normalizedFullName.split(' ').filter(Boolean);
    tokens.forEach((token) => keywords.add(token));
    if (tokens.length >= 2) {
      const first = tokens[0];
      const last = tokens[tokens.length - 1];
      keywords.add(`${first} ${last}`);
      keywords.add(`${first}${last}`);
    }
  }

  const normalizedUsername = normalizeUsername(username);
  if (normalizedUsername) {
    keywords.add(normalizedUsername);
    keywords.add(`@${normalizedUsername}`);
  }

  const emailLocalPart = (email || '').split('@')[0] ?? '';
  const normalizedEmail = normalizeUsername(emailLocalPart);
  if (normalizedEmail) {
    keywords.add(normalizedEmail);
  }

  return Array.from(keywords)
    .map((keyword) => keyword.trim())
    .filter((keyword) => keyword.length > 0)
    .slice(0, 50);
}

function serializeFirestoreData(admin, data) {
  if (!data || typeof data !== 'object') {
    return data;
  }

  const serialized = {};
  for (const [key, value] of Object.entries(data)) {
    if (value instanceof admin.firestore.Timestamp) {
      serialized[key] = value.toDate().toISOString();
    } else if (Array.isArray(value)) {
      serialized[key] = value.map((item) => serializeFirestoreData(admin, item));
    } else if (value && typeof value === 'object') {
      serialized[key] = serializeFirestoreData(admin, value);
    } else {
      serialized[key] = value;
    }
  }
  return serialized;
}

function createEnsureSqlUserHandler(admin) {
  return functions.region(REGION).https.onCall(async (data, context) => {
    if (!context.app) {
      throw new functions.https.HttpsError('failed-precondition', 'app_check_required');
    }

    if (!context.auth?.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Bu işlemi gerçekleştirmek için giriş yapmalısınız.');
    }

    const authUid = context.auth.uid;
    const rawUsername = (data?.username ?? '').toString().trim();
    const rawDisplayName = (data?.displayName ?? data?.fullName ?? '').toString().trim();
    const rawEmail = (data?.email ?? context.auth.token?.email ?? '').toString().trim();
    const rawAvatar = (data?.avatar ?? '').toString().trim();

    if (!rawUsername) {
      throw new functions.https.HttpsError('invalid-argument', 'username_required');
    }

    if (!rawEmail) {
      throw new functions.https.HttpsError('invalid-argument', 'email_required');
    }

    try {
      const usernameLower = normalizeUsername(rawUsername);
      const fullNameLower = normalizeFullName(rawDisplayName || rawUsername);
      const emailLower = normalizeEmail(rawEmail);
      const searchKeywords = generateSearchKeywords({
        fullName: rawDisplayName || rawUsername,
        username: rawUsername,
        email: rawEmail,
      });

      const { userId, created } = await executeProcedure(
        'ensureUser',
        {
          authUid,
          email: rawEmail,
          username: rawUsername,
          displayName: rawDisplayName || rawUsername,
        },
        { auth: context.auth }
      );

      const userRef = admin.firestore().collection('users').doc(authUid);
      const now = admin.firestore.FieldValue.serverTimestamp();
      const updates = {
        uid: authUid,
        authUid,
        sqlUserId: userId,
        username: rawUsername,
        usernameLower,
        displayName: rawDisplayName || rawUsername,
        fullName: rawDisplayName || rawUsername,
        fullNameLower,
        fullNameTokens: fullNameLower ? fullNameLower.split(' ').filter(Boolean) : [],
        email: rawEmail,
        emailLower,
        searchKeywords,
        avatar: rawAvatar || '👤',
        isVerified: context.auth.token?.email_verified === true,
        updatedAtUtc: now,
        lastActive: now,
      };

      if (created) {
        updates.createdAt = now;
        updates.joinDate = now;
        updates.rozetler = ['Yeni Üye'];
        updates.isPremium = false;
        updates.krepScore = 0;
        updates.followersCount = 0;
        updates.followingCount = 0;
      }

      await userRef.set(updates, { merge: true });
      const snapshot = await userRef.get();
      const profileData = snapshot.data() || {};

      functions.logger.info('ensureSqlUser.success', {
        uid: authUid,
        sqlUserId: userId,
        created,
      });

      return {
        sqlUserId: userId,
        created,
        profile: {
          id: snapshot.id,
          ...serializeFirestoreData(admin, profileData),
        },
      };
    } catch (error) {
      console.error('ensureSqlUser.error', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      if (error.code === 'ELOGIN') {
        throw new functions.https.HttpsError('failed-precondition', 'sql_login_failed');
      }
      if (error.code === 'ETIMEOUT') {
        throw new functions.https.HttpsError('deadline-exceeded', 'sql_timeout');
      }
      if (error.message === 'ENSURE_USER_NO_ID' || error.message === 'SQL_GATEWAY_NO_RESULT') {
        throw new functions.https.HttpsError('internal', 'sql_no_id_returned');
      }

      throw new functions.https.HttpsError('internal', 'ensure_sql_user_failed');
    }
  });
}

module.exports = {
  createEnsureSqlUserHandler,
};
