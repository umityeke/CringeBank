const { version } = require('../package.json');

const COMMANDS = new Set(['grant', 'revoke', 'list']);
const ROLE_ALIASES = new Map([
  ['superadmin', 'superadmin'],
  ['super-admin', 'superadmin'],
  ['system_writer', 'system_writer'],
  ['system-writer', 'system_writer'],
  ['systemwriter', 'system_writer'],
]);

function normalizeRole(roleInput) {
  if (!roleInput) {
    return null;
  }
  const normalized = ROLE_ALIASES.get(String(roleInput).toLowerCase());
  if (!normalized) {
    throw new Error(`Desteklenmeyen rol: ${roleInput}`);
  }
  return normalized;
}

function updateClaims(currentClaims, role, grant) {
  const claims = { ...(currentClaims || {}) };

  if (role === 'superadmin') {
    if (grant) {
      claims.admin = true;
      claims.superadmin = true;
      claims.role = 'superadmin';
      claims.grantedAt = Date.now();
    } else {
      delete claims.admin;
      delete claims.superadmin;
      if (claims.role === 'superadmin') {
        delete claims.role;
      }
    }
  }

  if (role === 'system_writer') {
    if (grant) {
      claims.system_writer = true;
      claims.backend = true;
    } else {
      delete claims.system_writer;
      delete claims.backend;
    }
  }

  return claims;
}

function buildFirestoreUpdates(role, grant, FieldValue) {
  if (!FieldValue || typeof FieldValue.serverTimestamp !== 'function') {
    throw new Error('FieldValue.serverTimestamp eksik');
  }

  const updates = {
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (role === 'superadmin') {
    updates.isSuperAdmin = grant;
    updates['roles.superadmin'] = grant;
  }

  if (role === 'system_writer') {
    updates.isSystemWriter = grant;
    updates['roles.systemWriter'] = grant;
  }

  return updates;
}

function createRoleManager({ auth, firestore, FieldValue }) {
  if (!auth || !firestore || !FieldValue) {
    throw new Error('RoleManager için auth, firestore ve FieldValue gereklidir');
  }

  async function resolveUser({ uid, email }) {
    if (uid) {
      return auth.getUser(uid);
    }
    if (!email) {
      throw new Error('Kullanıcıyı tespit etmek için uid veya email gerekli');
    }
    return auth.getUserByEmail(email);
  }

  async function applyRole({ uid, email, role, grant, notes = '', dryRun = false, executedBy = 'cli.manage_roles', user: providedUser }) {
    const user = providedUser || await resolveUser({ uid, email });
    const targetUid = user.uid;
    const targetEmail = user.email;

    const newClaims = updateClaims(user.customClaims, role, grant);
    const firestoreUpdates = buildFirestoreUpdates(role, grant, FieldValue);
    const auditEntry = {
      action: `${grant ? 'grant' : 'revoke'}:${role}`,
      targetUid,
      targetEmail,
      executedBy,
      notes,
      timestamp: FieldValue.serverTimestamp(),
      toolVersion: version,
    };

    if (dryRun) {
      return {
        user,
        newClaims,
        firestoreUpdates,
        auditEntry,
        persisted: false,
      };
    }

    await auth.setCustomUserClaims(targetUid, newClaims);
    await firestore.collection('users').doc(targetUid).set(firestoreUpdates, { merge: true });
    await firestore.collection('admin_audit').add(auditEntry);

    return {
      user,
      newClaims,
      firestoreUpdates,
      auditEntry,
      persisted: true,
    };
  }

  async function listRoles() {
    const result = [];
    let pageToken;

    do {
      const page = await auth.listUsers(1000, pageToken);
      page.users.forEach((userRecord) => {
        const claims = userRecord.customClaims || {};
        if (claims.superadmin || claims.system_writer) {
          result.push({
            uid: userRecord.uid,
            email: userRecord.email,
            displayName: userRecord.displayName,
            claims: {
              superadmin: Boolean(claims.superadmin),
              system_writer: Boolean(claims.system_writer),
              admin: Boolean(claims.admin),
              backend: Boolean(claims.backend),
              role: claims.role,
            },
          });
        }
      });
      pageToken = page.pageToken;
    } while (pageToken);

    result.sort((a, b) => (a.email || '').localeCompare(b.email || ''));
    return result;
  }

  return {
    applyRole,
    listRoles,
    resolveUser,
  };
}

module.exports = {
  COMMANDS,
  ROLE_ALIASES,
  normalizeRole,
  updateClaims,
  buildFirestoreUpdates,
  createRoleManager,
};
