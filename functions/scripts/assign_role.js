#!/usr/bin/env node

/**
 * Admin Token Management Script
 * 
 * Assigns custom claims for RBAC roles to Firebase users.
 * Roles: user, system_writer, superadmin
 * 
 * Usage:
 *   node scripts/assign_role.js <uid> <role>
 * 
 * Examples:
 *   node scripts/assign_role.js abc123def456 system_writer
 *   node scripts/assign_role.js abc123def456 superadmin
 *   node scripts/assign_role.js abc123def456 user
 * 
 * Environment:
 *   FIREBASE_PROJECT_ID - Firebase project ID
 *   GOOGLE_APPLICATION_CREDENTIALS - Path to service account JSON
 */

const admin = require('firebase-admin');

const VALID_ROLES = ['user', 'system_writer', 'superadmin'];

async function assignRole(uid, role) {
  if (!uid || uid.trim().length === 0) {
    throw new Error('UID is required');
  }

  if (!role || !VALID_ROLES.includes(role.toLowerCase())) {
    throw new Error(`Invalid role. Must be one of: ${VALID_ROLES.join(', ')}`);
  }

  const normalizedRole = role.toLowerCase();

  try {
    const userRecord = await admin.auth().getUser(uid);
    console.log(`User: ${userRecord.email || userRecord.uid}`);
    console.log(`Current claims: ${JSON.stringify(userRecord.customClaims || {})}`);

    await admin.auth().setCustomUserClaims(uid, {
      role: normalizedRole,
      assignedAt: new Date().toISOString(),
    });

    console.log(`✅ Successfully assigned role '${normalizedRole}' to user ${uid}`);

    const updatedRecord = await admin.auth().getUser(uid);
    console.log(`New claims: ${JSON.stringify(updatedRecord.customClaims)}`);

    return { success: true, uid, role: normalizedRole };
  } catch (error) {
    console.error(`❌ Failed to assign role: ${error.message}`);
    throw error;
  }
}

async function revokeRole(uid) {
  if (!uid || uid.trim().length === 0) {
    throw new Error('UID is required');
  }

  try {
    const userRecord = await admin.auth().getUser(uid);
    console.log(`User: ${userRecord.email || userRecord.uid}`);
    console.log(`Current claims: ${JSON.stringify(userRecord.customClaims || {})}`);

    await admin.auth().setCustomUserClaims(uid, {
      role: 'user',
      revokedAt: new Date().toISOString(),
    });

    console.log(`✅ Successfully revoked elevated role for user ${uid} (reset to 'user')`);

    const updatedRecord = await admin.auth().getUser(uid);
    console.log(`New claims: ${JSON.stringify(updatedRecord.customClaims)}`);

    return { success: true, uid, role: 'user' };
  } catch (error) {
    console.error(`❌ Failed to revoke role: ${error.message}`);
    throw error;
  }
}

async function listUserRoles(uids) {
  if (!uids || uids.length === 0) {
    throw new Error('At least one UID is required');
  }

  console.log('Fetching user roles...\n');

  for (const uid of uids) {
    try {
      const userRecord = await admin.auth().getUser(uid.trim());
      const claims = userRecord.customClaims || {};
      const role = claims.role || 'user';

      console.log(`UID: ${uid}`);
      console.log(`  Email: ${userRecord.email || 'N/A'}`);
      console.log(`  Role: ${role}`);
      console.log(`  Claims: ${JSON.stringify(claims)}\n`);
    } catch (error) {
      console.error(`❌ Failed to fetch user ${uid}: ${error.message}\n`);
    }
  }
}

async function main() {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command) {
    console.log(`
Admin Token Management

Usage:
  node scripts/assign_role.js assign <uid> <role>
  node scripts/assign_role.js revoke <uid>
  node scripts/assign_role.js list <uid1> [uid2] [uid3]...

Roles: ${VALID_ROLES.join(', ')}

Examples:
  node scripts/assign_role.js assign abc123 system_writer
  node scripts/assign_role.js revoke abc123
  node scripts/assign_role.js list abc123 def456
    `);
    process.exit(0);
  }

  // Initialize Firebase Admin
  if (!admin.apps.length) {
    const projectId = process.env.FIREBASE_PROJECT_ID || process.env.GCLOUD_PROJECT;
    const credentials = process.env.GOOGLE_APPLICATION_CREDENTIALS;

    if (!projectId) {
      console.error('❌ FIREBASE_PROJECT_ID environment variable is required');
      process.exit(1);
    }

    if (credentials) {
      admin.initializeApp({
        credential: admin.credential.cert(credentials),
        projectId,
      });
    } else {
      admin.initializeApp({ projectId });
    }

    console.log(`📦 Initialized Firebase Admin for project: ${projectId}\n`);
  }

  try {
    switch (command.toLowerCase()) {
      case 'assign': {
        const uid = args[1];
        const role = args[2];
        await assignRole(uid, role);
        break;
      }

      case 'revoke': {
        const uid = args[1];
        await revokeRole(uid);
        break;
      }

      case 'list': {
        const uids = args.slice(1);
        await listUserRoles(uids);
        break;
      }

      default:
        console.error(`❌ Unknown command: ${command}`);
        console.log('Valid commands: assign, revoke, list');
        process.exit(1);
    }

    process.exit(0);
  } catch (error) {
    console.error(`\n❌ Error: ${error.message}`);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  assignRole,
  revokeRole,
  listUserRoles,
};
