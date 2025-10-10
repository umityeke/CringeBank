const functions = require('./regional_functions');
const admin = require('firebase-admin');

const REGION = 'europe-west1';
const USERS_COLLECTION_PATH = 'users/{userId}';
const MANAGED_CLAIMS = new Set(['claims_version', 'user_status', 'moderator', 'admin', 'superadmin']);
const ALLOWED_STATUSES = new Set(['active', 'disabled', 'banned', 'deleted']);

const toLowerString = (value) => (value ?? '').toString().trim().toLowerCase();

const resolveRoleFlags = (data) => {
  const role = toLowerString(data.role ?? data.userRole);
  const rolesArray = Array.isArray(data.roles)
    ? data.roles
        .map((item) => toLowerString(item))
        .filter((item) => item.length > 0)
    : [];

  const explicitSuperAdmin = data.superadmin === true || data.isSuperAdmin === true;
  const explicitAdmin = data.admin === true || data.isAdmin === true;
  const explicitModerator =
    data.moderator === true ||
    data.isModerator === true ||
    data.moderated === true;

  const isSuperAdmin =
    explicitSuperAdmin ||
    role === 'superadmin' ||
    rolesArray.includes('superadmin');

  const isAdmin =
    isSuperAdmin ||
    explicitAdmin ||
    role === 'admin' ||
    rolesArray.includes('admin');

  const isModerator =
    isSuperAdmin ||
    isAdmin ||
    explicitModerator ||
    role === 'moderator' ||
    rolesArray.includes('moderator');

  return {
    isSuperAdmin,
    isAdmin,
    isModerator,
    signature: `${isSuperAdmin ? '1' : '0'}${isAdmin ? '1' : '0'}${isModerator ? '1' : '0'}`,
  };
};

const normalizeStatus = (data) => {
  let status = toLowerString(data.status ?? data.userStatus ?? data.state);

  if (data.isBanned === true || data.banned === true) {
    status = 'banned';
  } else if (data.deleted === true || data.deletedAt || data.deletedAtUtc) {
    status = 'deleted';
  } else if (data.isDisabled === true || data.disabled === true || data.disabledAt || data.disabledAtUtc) {
    status = 'disabled';
  }

  if (!ALLOWED_STATUSES.has(status)) {
    status = 'active';
  }

  return status;
};

const pickClaimsVersion = (value) => {
  const parsed = Number(value);
  if (Number.isFinite(parsed) && parsed > 0) {
    return Math.floor(parsed);
  }

  return 0;
};

const buildTargetClaims = (existingClaims, flags, status, version) => {
  const result = {};

  if (existingClaims && typeof existingClaims === 'object') {
    for (const [key, value] of Object.entries(existingClaims)) {
      if (!MANAGED_CLAIMS.has(key)) {
        result[key] = value;
      }
    }
  }

  result.claims_version = version;
  result.user_status = status;

  if (flags.isSuperAdmin) {
    result.superadmin = true;
    result.admin = true;
    result.moderator = true;
  } else {
    if (flags.isAdmin) {
      result.admin = true;
    }

    if (flags.isModerator) {
      result.moderator = true;
    }
  }

  return result;
};

const claimsAreEqual = (left, right) => {
  if (left === right) {
    return true;
  }

  if (!left || typeof left !== 'object') {
    return Object.keys(right || {}).length === 0;
  }

  if (!right || typeof right !== 'object') {
    return Object.keys(left).length === 0;
  }

  const leftKeys = Object.keys(left).sort();
  const rightKeys = Object.keys(right).sort();

  if (leftKeys.length !== rightKeys.length) {
    return false;
  }

  for (let i = 0; i < leftKeys.length; i += 1) {
    if (leftKeys[i] !== rightKeys[i]) {
      return false;
    }

    if (left[leftKeys[i]] !== right[rightKeys[i]]) {
      return false;
    }
  }

  return true;
};

const shouldDisableUser = (status) => status !== 'active';

const syncClaimsForUser = async (userId, data, previousData, documentRef) => {
  const normalizedStatus = normalizeStatus(data);
  const roleFlags = resolveRoleFlags(data);
  const previousStatus = previousData ? normalizeStatus(previousData) : undefined;
  const previousRoleFlags = previousData ? resolveRoleFlags(previousData) : undefined;

  const userRecord = await admin.auth().getUser(userId);
  const existingClaims = userRecord.customClaims || {};

  const currentClaimsVersion = pickClaimsVersion(data.claimsVersion ?? data.claims_version);

  const statusChanged = previousStatus === undefined || normalizedStatus !== previousStatus;
  const rolesChanged =
    previousRoleFlags === undefined || roleFlags.signature !== previousRoleFlags.signature;

  let targetClaimsVersion = currentClaimsVersion;

  if (statusChanged || rolesChanged || targetClaimsVersion === 0) {
    targetClaimsVersion += 1;
  }

  const targetClaims = buildTargetClaims(existingClaims, roleFlags, normalizedStatus, targetClaimsVersion);

  const disableAuth = shouldDisableUser(normalizedStatus);

  const updates = {
    claimsVersion: targetClaimsVersion,
    status: normalizedStatus,
    claimsLastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const claimsChanged = !claimsAreEqual(existingClaims, targetClaims);
  const disabledChanged = userRecord.disabled !== disableAuth;

  if (!claimsChanged && !disabledChanged && currentClaimsVersion === targetClaimsVersion) {
    // Nothing to do; ensure status stored consistently if missing
    if (
      data.status !== normalizedStatus ||
      data.claimsVersion !== targetClaimsVersion ||
      data.claims_version !== targetClaimsVersion
    ) {
      const targetRef = documentRef ?? admin.firestore().doc(`users/${userId}`);
  await targetRef.set(updates, { merge: true });
    }
    return null;
  }

  if (claimsChanged) {
    await admin.auth().setCustomUserClaims(userId, targetClaims);
  }

  if (disabledChanged) {
    await admin.auth().updateUser(userId, { disabled: disableAuth });
  }

  const targetRef = documentRef ?? admin.firestore().doc(`users/${userId}`);
  await targetRef.set(updates, { merge: true });

  functions.logger.info('User claims synchronized', {
    uid: userId,
    status: normalizedStatus,
    claimsVersion: targetClaimsVersion,
    roles: roleFlags,
    disabled: disableAuth,
  });

  return null;
};

exports.syncUserClaimsOnUserWrite = functions
  .region(REGION)
  .firestore.document(USERS_COLLECTION_PATH)
  .onWrite(async (change, context) => {
    const { userId } = context.params;

    if (!change.after.exists) {
      try {
        await admin.auth().setCustomUserClaims(userId, {});
      } catch (error) {
        if (error.code !== 'auth/user-not-found') {
          functions.logger.error('Failed to clear custom claims for deleted user', {
            uid: userId,
            error: error.message,
          });
        }
      }

      try {
        await admin.auth().updateUser(userId, { disabled: true });
      } catch (error) {
        if (error.code !== 'auth/user-not-found') {
          functions.logger.error('Failed to disable deleted user', {
            uid: userId,
            error: error.message,
          });
        }
      }

      return null;
    }

    const data = change.after.data() || {};
    const previousData = change.before.exists ? change.before.data() || {} : undefined;

    try {
  await syncClaimsForUser(userId, data, previousData, change.after.ref);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        functions.logger.warn('User document exists but auth user missing', {
          uid: userId,
        });
        return null;
      }

      functions.logger.error('Failed to synchronize user claims', {
        uid: userId,
        error: error.message,
      });

      throw error;
    }

    return null;
  });

exports.refreshUserClaims = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    if (!context.auth || context.auth.token?.superadmin !== true) {
      throw new functions.https.HttpsError('permission-denied', 'Yetkili değilsiniz.');
    }

    const userId = (data?.uid ?? data?.userId ?? context.auth.uid ?? '').toString().trim();

    if (userId.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Kullanıcı kimliği gerekli.');
    }

    const snapshot = await admin.firestore().doc(`users/${userId}`).get();

    if (!snapshot.exists) {
      throw new functions.https.HttpsError('not-found', 'Kullanıcı profili bulunamadı.');
    }

  await syncClaimsForUser(userId, snapshot.data() || {}, undefined, snapshot.ref);

    return { success: true };
  });
