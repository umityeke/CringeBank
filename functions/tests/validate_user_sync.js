#!/usr/bin/env node

/**
 * Validation Test: Firebase ↔ SQL User Sync Round Trip
 * 
 * Tests:
 * 1. Create Firebase user
 * 2. Verify SQL user created via trigger
 * 3. Fetch user via ensureSqlUser callable
 * 4. Validate UID match between Firebase and SQL
 * 5. Clean up test user
 * 
 * Prerequisites:
 * - Firebase emulator running or valid credentials
 * - SQL Server accessible with test database
 * - Environment variables configured
 * 
 * Usage:
 *   node tests/validate_user_sync.js
 */

const admin = require('firebase-admin');
const { executeProcedure } = require('../sql_gateway');

const TEST_EMAIL_PREFIX = 'test_sync_';
const CLEANUP_AFTER_TEST = true;

function generateTestEmail() {
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(7);
  return `${TEST_EMAIL_PREFIX}${timestamp}_${random}@cringebank.test`;
}

async function createTestFirebaseUser(email, password = 'TestPass123!') {
  try {
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: `Test User ${email.split('@')[0]}`,
      emailVerified: false,
    });

    console.log(`✅ Created Firebase user: ${userRecord.uid} (${email})`);
    return userRecord;
  } catch (error) {
    console.error(`❌ Failed to create Firebase user: ${error.message}`);
    throw error;
  }
}

async function waitForSqlSync(authUid, maxWaitMs = 10000, pollIntervalMs = 500) {
  const startTime = Date.now();
  let attempts = 0;

  while (Date.now() - startTime < maxWaitMs) {
    attempts++;
    try {
      const result = await executeProcedure(
        'getUserProfile',
        { authUid },
        { skipAuth: true }
      );

      if (result && result.userId) {
        console.log(`✅ SQL user found after ${attempts} attempts (${Date.now() - startTime}ms)`);
        console.log(`   SQL User ID: ${result.userId}`);
        console.log(`   Email: ${result.email}`);
        console.log(`   Username: ${result.username}`);
        return result;
      }
    } catch (error) {
      // User not found yet, continue polling
      if (error.code !== 'NOT_FOUND' && error.code !== 'EREQUEST') {
        console.warn(`⚠️  Unexpected error during poll: ${error.message}`);
      }
    }

    await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
  }

  throw new Error(`SQL sync timeout after ${maxWaitMs}ms (${attempts} attempts)`);
}

async function validateUidMatch(firebaseUid, sqlAuthUid) {
  if (firebaseUid !== sqlAuthUid) {
    throw new Error(`UID mismatch! Firebase: ${firebaseUid}, SQL: ${sqlAuthUid}`);
  }
  console.log(`✅ UID match validated: ${firebaseUid}`);
  return true;
}

async function cleanupTestUser(uid, email) {
  if (!CLEANUP_AFTER_TEST) {
    console.log(`⏭️  Cleanup skipped (CLEANUP_AFTER_TEST=false)`);
    return;
  }

  try {
    await admin.auth().deleteUser(uid);
    console.log(`✅ Cleaned up Firebase user: ${uid}`);

    // Note: SQL user soft-delete handled by onUserDeleted trigger
    // Or manually delete from SQL if needed
  } catch (error) {
    console.error(`❌ Failed to cleanup Firebase user: ${error.message}`);
  }

  try {
    await admin.firestore().collection('users').doc(uid).delete();
    console.log(`✅ Cleaned up Firestore document`);
  } catch (error) {
    console.error(`❌ Failed to cleanup Firestore: ${error.message}`);
  }
}

async function runRoundTripTest() {
  console.log('\n🧪 Starting Firebase ↔ SQL User Sync Round Trip Test\n');

  const testEmail = generateTestEmail();
  let testUser = null;

  try {
    // Step 1: Create Firebase user
    console.log('Step 1: Creating Firebase user...');
    testUser = await createTestFirebaseUser(testEmail);

    // Step 2: Wait for SQL sync (via onUserCreated trigger)
    console.log('\nStep 2: Waiting for SQL sync...');
    const sqlUser = await waitForSqlSync(testUser.uid);

    // Step 3: Validate UID match
    console.log('\nStep 3: Validating UID match...');
    await validateUidMatch(testUser.uid, sqlUser.authUid);

    // Step 4: Test ensureSqlUser callable (should return existing user)
    console.log('\nStep 4: Testing ensureSqlUser callable...');
    const ensureResult = await executeProcedure(
      'ensureUser',
      {
        authUid: testUser.uid,
        email: testEmail,
        username: testEmail.split('@')[0],
        displayName: testUser.displayName,
      },
      { skipAuth: true }
    );

    if (ensureResult.created) {
      console.warn('⚠️  ensureSqlUser reported created=true for existing user');
    } else {
      console.log('✅ ensureSqlUser correctly returned existing user');
    }

    console.log(`   SQL User ID: ${ensureResult.userId}`);

    // Step 5: Cleanup
    console.log('\nStep 5: Cleaning up test user...');
    await cleanupTestUser(testUser.uid, testEmail);

    console.log('\n✅ Round trip test PASSED\n');
    return { success: true };
  } catch (error) {
    console.error(`\n❌ Round trip test FAILED: ${error.message}\n`);
    console.error(error.stack);

    if (testUser) {
      console.log('\nAttempting cleanup after failure...');
      await cleanupTestUser(testUser.uid, testEmail);
    }

    return { success: false, error: error.message };
  }
}

async function main() {
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

    console.log(`📦 Initialized Firebase Admin for project: ${projectId}`);
  }

  const result = await runRoundTripTest();
  process.exit(result.success ? 0 : 1);
}

if (require.main === module) {
  main();
}

module.exports = {
  runRoundTripTest,
};
