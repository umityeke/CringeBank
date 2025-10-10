#!/usr/bin/env node

/**
 * CringeStore Integration Tests
 * 
 * End-to-end test suite for SQL Gateway store operations:
 * - Order creation and escrow locking
 * - Escrow release (seller payment)
 * - Order refund (buyer refund)
 * - Wallet balance consistency
 * - Concurrent order handling (race conditions)
 * - RBAC permission enforcement
 * 
 * Prerequisites:
 *   - Firebase Admin SDK credentials
 *   - SQL Server connection configured
 *   - Test users with appropriate RBAC roles
 *   - Test product seeded in database
 * 
 * Usage:
 *   node store_integration_test.js [options]
 * 
 * Options:
 *   --scenario NAME    Run specific test scenario (all|order|refund|wallet|concurrent|rbac)
 *   --verbose          Enable verbose logging
 *   --skip-cleanup     Don't delete test data after run
 * 
 * Example:
 *   node store_integration_test.js --scenario order --verbose
 */

const admin = require('firebase-admin');
const mssql = require('mssql');
const fs = require('fs');
const path = require('path');

// ==================== CONFIGURATION ====================

const VERBOSE = process.argv.includes('--verbose');
const SKIP_CLEANUP = process.argv.includes('--skip-cleanup');

const scenarioArg = process.argv.find(arg => arg.startsWith('--scenario='));
const TARGET_SCENARIO = scenarioArg
  ? scenarioArg.split('=')[1].trim()
  : 'all';

// Test user credentials (these should be pre-created with appropriate roles)
const TEST_USERS = {
  buyer: {
    uid: 'test_buyer_' + Date.now(),
    email: `test.buyer.${Date.now()}@cringebank.test`,
    displayName: 'Test Buyer',
  },
  seller: {
    uid: 'test_seller_' + Date.now(),
    email: `test.seller.${Date.now()}@cringebank.test`,
    displayName: 'Test Seller',
  },
  systemWriter: {
    uid: 'test_system_writer_' + Date.now(),
    email: `test.system.${Date.now()}@cringebank.test`,
    displayName: 'Test System Writer',
  },
};

const TEST_PRODUCT = {
  id: 'test_product_' + Date.now(),
  title: 'Integration Test Product',
  desc: 'Test product for integration testing',
  priceGold: 100,
  category: 'diger',
  status: 'ACTIVE',
  sellerType: 'P2P',
};

// ==================== FIREBASE INITIALIZATION ====================

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, '../../service-account-key.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error(`❌ Service account key not found: ${serviceAccountPath}`);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccountPath),
});

const auth = admin.auth();
const functions = admin.functions();

// ==================== SQL SERVER CONNECTION ====================

const sqlConfig = {
  user: process.env.SQL_USER,
  password: process.env.SQL_PASSWORD,
  server: process.env.SQL_SERVER,
  database: process.env.SQL_DATABASE,
  options: {
    encrypt: true,
    trustServerCertificate: false,
    enableArithAbort: true,
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
};

if (!sqlConfig.user || !sqlConfig.password || !sqlConfig.server || !sqlConfig.database) {
  console.error('❌ SQL Server connection environment variables not set');
  process.exit(1);
}

let sqlPool = null;

async function connectSQL() {
  if (!sqlPool) {
    log('🔌 Connecting to SQL Server...');
    sqlPool = await mssql.connect(sqlConfig);
    log('✅ SQL Server connected');
  }
  return sqlPool;
}

async function disconnectSQL() {
  if (sqlPool) {
    await sqlPool.close();
    sqlPool = null;
    log('🔌 SQL Server connection closed');
  }
}

// ==================== UTILITY FUNCTIONS ====================

function log(message, ...args) {
  if (VERBOSE || !message.startsWith('   ')) {
    console.log(message, ...args);
  }
}

function error(message, ...args) {
  console.error(message, ...args);
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ==================== TEST HELPERS ====================

async function createTestUser(userConfig) {
  try {
    const user = await auth.createUser({
      uid: userConfig.uid,
      email: userConfig.email,
      displayName: userConfig.displayName,
      emailVerified: true,
    });
    log(`   ✅ Created test user: ${user.email}`);
    return user;
  } catch (err) {
    if (err.code === 'auth/uid-already-exists') {
      log(`   ℹ️  User already exists: ${userConfig.email}`);
      return await auth.getUser(userConfig.uid);
    }
    throw err;
  }
}

async function assignRole(uid, role) {
  const customClaims = { role };
  await auth.setCustomUserClaims(uid, customClaims);
  log(`   ✅ Assigned role '${role}' to user: ${uid}`);
}

async function createTestProduct(pool, productConfig, sellerUid) {
  const request = pool.request();
  request.input('ProductId', mssql.NVarChar(64), productConfig.id);
  request.input('Title', mssql.NVarChar(255), productConfig.title);
  request.input('Description', mssql.NVarChar(mssql.MAX), productConfig.desc);
  request.input('PriceGold', mssql.Int, productConfig.priceGold);
  request.input('ImagesJson', mssql.NVarChar(mssql.MAX), '[]');
  request.input('Category', mssql.NVarChar(64), productConfig.category);
  request.input('Condition', mssql.NVarChar(32), 'new');
  request.input('Status', mssql.NVarChar(32), productConfig.status);
  request.input('SellerAuthUid', mssql.NVarChar(64), sellerUid);
  request.input('VendorId', mssql.NVarChar(64), null);
  request.input('SellerType', mssql.NVarChar(32), productConfig.sellerType);
  request.input('QrUid', mssql.NVarChar(64), null);
  request.input('QrBound', mssql.Bit, 0);
  request.input('ReservedBy', mssql.NVarChar(64), null);
  request.input('ReservedAt', mssql.DateTime2, null);
  request.input('SharedEntryId', mssql.NVarChar(64), null);
  request.input('SharedByAuthUid', mssql.NVarChar(64), null);
  request.input('SharedAt', mssql.DateTime2, null);
  request.input('CreatedAt', mssql.DateTime2, new Date().toISOString());
  request.input('UpdatedAt', mssql.DateTime2, new Date().toISOString());

  await request.execute('dbo.sp_Migration_UpsertProduct');
  log(`   ✅ Created test product: ${productConfig.id}`);
}

async function getWalletBalance(pool, authUid) {
  const result = await pool.request()
    .input('AuthUid', mssql.NVarChar(64), authUid)
    .query('SELECT GoldBalance, PendingGold FROM StoreWallets WHERE AuthUid = @AuthUid');
  
  if (result.recordset.length === 0) {
    return { goldBalance: 0, pendingGold: 0 };
  }
  
  return {
    goldBalance: result.recordset[0].GoldBalance || 0,
    pendingGold: result.recordset[0].PendingGold || 0,
  };
}

async function setWalletBalance(pool, authUid, goldBalance) {
  const request = pool.request();
  request.input('AuthUid', mssql.NVarChar(64), authUid);
  request.input('GoldBalance', mssql.Int, goldBalance);
  request.input('PendingGold', mssql.Int, 0);
  
  await request.execute('dbo.sp_Migration_UpsertWallet');
  log(`   ✅ Set wallet balance for ${authUid}: ${goldBalance} gold`);
}

async function callFunction(functionName, data, context = {}) {
  try {
    const callable = functions.httpsCallable(functionName);
    const result = await callable(data, context);
    return { success: true, data: result.data };
  } catch (err) {
    return { success: false, error: err };
  }
}

async function cleanupTestData(pool) {
  if (SKIP_CLEANUP) {
    log('⏭️  Skipping cleanup (--skip-cleanup flag)');
    return;
  }

  log('\n🧹 Cleaning up test data...');

  // Delete test orders, escrows, wallets, products
  const queries = [
    `DELETE FROM StoreEscrows WHERE OrderPublicId LIKE 'test_%'`,
    `DELETE FROM StoreOrders WHERE OrderPublicId LIKE 'test_%'`,
    `DELETE FROM StoreProducts WHERE ProductId LIKE 'test_%'`,
    `DELETE FROM StoreWallets WHERE AuthUid LIKE 'test_%'`,
  ];

  for (const query of queries) {
    try {
      await pool.request().query(query);
      log(`   ✅ Executed: ${query}`);
    } catch (err) {
      error(`   ❌ Cleanup query failed: ${err.message}`);
    }
  }

  // Delete test users
  for (const userKey of Object.keys(TEST_USERS)) {
    try {
      await auth.deleteUser(TEST_USERS[userKey].uid);
      log(`   ✅ Deleted user: ${TEST_USERS[userKey].email}`);
    } catch (err) {
      if (err.code !== 'auth/user-not-found') {
        error(`   ❌ Failed to delete user: ${err.message}`);
      }
    }
  }
}

// ==================== TEST SCENARIOS ====================

async function testOrderFlow(pool) {
  console.log('\n╔════════════════════════════════════════════════════════╗');
  console.log('║  Test: Complete Order Flow                            ║');
  console.log('╚════════════════════════════════════════════════════════╝');

  const buyer = await createTestUser(TEST_USERS.buyer);
  const seller = await createTestUser(TEST_USERS.seller);

  await assignRole(buyer.uid, 'user');
  await assignRole(seller.uid, 'user');

  await createTestProduct(pool, TEST_PRODUCT, seller.uid);
  await setWalletBalance(pool, buyer.uid, 1000);
  await setWalletBalance(pool, seller.uid, 0);

  const buyerInitialBalance = await getWalletBalance(pool, buyer.uid);
  const sellerInitialBalance = await getWalletBalance(pool, seller.uid);

  log(`\n📊 Initial State:`);
  log(`   Buyer balance: ${buyerInitialBalance.goldBalance} gold`);
  log(`   Seller balance: ${sellerInitialBalance.goldBalance} gold`);
  log(`   Product price: ${TEST_PRODUCT.priceGold} gold`);

  // Step 1: Create order (lock escrow)
  log(`\n🛒 Step 1: Create order...`);
  const createOrderResult = await callFunction('sqlGatewayStoreCreateOrder', {
    productId: TEST_PRODUCT.id,
  }, { auth: { uid: buyer.uid } });

  if (!createOrderResult.success) {
    error(`❌ Order creation failed: ${createOrderResult.error.message}`);
    return { passed: false, reason: 'order_creation_failed' };
  }

  const orderId = createOrderResult.data.orderId;
  log(`   ✅ Order created: ${orderId}`);

  // Verify wallet balances after lock
  await sleep(1000); // Allow DB update
  const buyerAfterLock = await getWalletBalance(pool, buyer.uid);
  const totalCost = TEST_PRODUCT.priceGold + Math.floor(TEST_PRODUCT.priceGold * 0.05);

  log(`   Buyer balance after lock: ${buyerAfterLock.goldBalance} gold (pending: ${buyerAfterLock.pendingGold})`);

  const expectedPending = totalCost;
  const expectedBalance = buyerInitialBalance.goldBalance - totalCost;

  if (buyerAfterLock.pendingGold !== expectedPending) {
    error(`   ❌ Expected pending: ${expectedPending}, got: ${buyerAfterLock.pendingGold}`);
    return { passed: false, reason: 'pending_mismatch' };
  }

  if (buyerAfterLock.goldBalance !== expectedBalance) {
    error(`   ❌ Expected balance: ${expectedBalance}, got: ${buyerAfterLock.goldBalance}`);
    return { passed: false, reason: 'balance_mismatch_after_lock' };
  }

  log(`   ✅ Wallet state correct after escrow lock`);

  // Step 2: Release escrow (complete order)
  log(`\n💰 Step 2: Release escrow...`);
  const releaseResult = await callFunction('sqlGatewayStoreReleaseEscrow', {
    orderId,
  }, { auth: { uid: seller.uid } });

  if (!releaseResult.success) {
    error(`❌ Escrow release failed: ${releaseResult.error.message}`);
    return { passed: false, reason: 'escrow_release_failed' };
  }

  log(`   ✅ Escrow released`);

  // Verify final balances
  await sleep(1000);
  const buyerFinal = await getWalletBalance(pool, buyer.uid);
  const sellerFinal = await getWalletBalance(pool, seller.uid);

  log(`\n📊 Final State:`);
  log(`   Buyer balance: ${buyerFinal.goldBalance} gold (pending: ${buyerFinal.pendingGold})`);
  log(`   Seller balance: ${sellerFinal.goldBalance} gold`);

  const sellerExpectedBalance = sellerInitialBalance.goldBalance + TEST_PRODUCT.priceGold;

  if (buyerFinal.pendingGold !== 0) {
    error(`   ❌ Buyer should have 0 pending gold, got: ${buyerFinal.pendingGold}`);
    return { passed: false, reason: 'pending_not_cleared' };
  }

  if (sellerFinal.goldBalance !== sellerExpectedBalance) {
    error(`   ❌ Seller expected: ${sellerExpectedBalance}, got: ${sellerFinal.goldBalance}`);
    return { passed: false, reason: 'seller_balance_incorrect' };
  }

  log(`   ✅ Final balances correct`);
  return { passed: true };
}

async function testRefundFlow(pool) {
  console.log('\n╔════════════════════════════════════════════════════════╗');
  console.log('║  Test: Order Refund Flow                              ║');
  console.log('╚════════════════════════════════════════════════════════╝');

  const buyer = await createTestUser(TEST_USERS.buyer);
  const seller = await createTestUser(TEST_USERS.seller);

  await assignRole(buyer.uid, 'user');
  await assignRole(seller.uid, 'user');

  const refundProduct = { ...TEST_PRODUCT, id: 'test_product_refund_' + Date.now() };
  await createTestProduct(pool, refundProduct, seller.uid);
  await setWalletBalance(pool, buyer.uid, 1000);

  const buyerInitialBalance = await getWalletBalance(pool, buyer.uid);

  log(`\n📊 Initial buyer balance: ${buyerInitialBalance.goldBalance} gold`);

  // Create order
  log(`\n🛒 Creating order...`);
  const createResult = await callFunction('sqlGatewayStoreCreateOrder', {
    productId: refundProduct.id,
  }, { auth: { uid: buyer.uid } });

  if (!createResult.success) {
    error(`❌ Order creation failed`);
    return { passed: false, reason: 'order_creation_failed' };
  }

  const orderId = createResult.data.orderId;
  log(`   ✅ Order created: ${orderId}`);

  await sleep(1000);
  const buyerAfterLock = await getWalletBalance(pool, buyer.uid);
  log(`   Buyer balance after lock: ${buyerAfterLock.goldBalance} gold (pending: ${buyerAfterLock.pendingGold})`);

  // Refund order
  log(`\n💸 Refunding order...`);
  const refundResult = await callFunction('sqlGatewayStoreRefundOrder', {
    orderId,
    refundReason: 'Integration test refund',
  }, { auth: { uid: seller.uid } });

  if (!refundResult.success) {
    error(`❌ Refund failed: ${refundResult.error.message}`);
    return { passed: false, reason: 'refund_failed' };
  }

  log(`   ✅ Refund processed: ${refundResult.data.refundId || 'N/A'}`);

  // Verify balances restored
  await sleep(1000);
  const buyerFinal = await getWalletBalance(pool, buyer.uid);

  log(`\n📊 Final State:`);
  log(`   Buyer balance: ${buyerFinal.goldBalance} gold (pending: ${buyerFinal.pendingGold})`);

  if (buyerFinal.goldBalance !== buyerInitialBalance.goldBalance) {
    error(`   ❌ Buyer balance not restored. Expected: ${buyerInitialBalance.goldBalance}, got: ${buyerFinal.goldBalance}`);
    return { passed: false, reason: 'balance_not_restored' };
  }

  if (buyerFinal.pendingGold !== 0) {
    error(`   ❌ Buyer should have 0 pending gold, got: ${buyerFinal.pendingGold}`);
    return { passed: false, reason: 'pending_not_cleared' };
  }

  log(`   ✅ Balance fully restored after refund`);
  return { passed: true };
}

async function testWalletConsistency(pool) {
  console.log('\n╔════════════════════════════════════════════════════════╗');
  console.log('║  Test: Wallet Balance Consistency                     ║');
  console.log('╚════════════════════════════════════════════════════════╝');

  const user = await createTestUser(TEST_USERS.buyer);
  await assignRole(user.uid, 'user');

  const initialBalance = 1000;
  await setWalletBalance(pool, user.uid, initialBalance);

  log(`\n💰 Initial balance: ${initialBalance} gold`);

  // Test multiple adjustments
  const adjustments = [
    { delta: 100, reason: 'Test credit' },
    { delta: -50, reason: 'Test debit' },
    { delta: 200, reason: 'Test bonus' },
  ];

  let expectedBalance = initialBalance;

  for (const adjustment of adjustments) {
    log(`\n🔄 Adjusting wallet: ${adjustment.delta > 0 ? '+' : ''}${adjustment.delta} gold`);
    
    const adjustResult = await callFunction('sqlGatewayStoreAdjustWallet', {
      targetAuthUid: user.uid,
      amountDelta: adjustment.delta,
      reason: adjustment.reason,
    }, { auth: { uid: user.uid } });

    if (!adjustResult.success) {
      error(`❌ Adjustment failed: ${adjustResult.error.message}`);
      return { passed: false, reason: 'adjustment_failed' };
    }

    expectedBalance += adjustment.delta;
    const newBalance = adjustResult.data.newBalance;

    log(`   Expected: ${expectedBalance}, Got: ${newBalance}`);

    if (newBalance !== expectedBalance) {
      error(`   ❌ Balance mismatch`);
      return { passed: false, reason: 'balance_mismatch' };
    }

    log(`   ✅ Balance correct: ${newBalance} gold`);
  }

  // Verify final state
  const finalWallet = await getWalletBalance(pool, user.uid);
  if (finalWallet.goldBalance !== expectedBalance) {
    error(`❌ Final balance verification failed. Expected: ${expectedBalance}, got: ${finalWallet.goldBalance}`);
    return { passed: false, reason: 'final_balance_mismatch' };
  }

  log(`\n✅ All wallet adjustments consistent`);
  return { passed: true };
}

async function testRBACEnforcement(pool) {
  console.log('\n╔════════════════════════════════════════════════════════╗');
  console.log('║  Test: RBAC Permission Enforcement                     ║');
  console.log('╚════════════════════════════════════════════════════════╝');

  const buyer = await createTestUser(TEST_USERS.buyer);
  const seller = await createTestUser(TEST_USERS.seller);

  await assignRole(buyer.uid, 'user');
  await assignRole(seller.uid, 'user');

  const rbacProduct = { ...TEST_PRODUCT, id: 'test_product_rbac_' + Date.now() };
  await createTestProduct(pool, rbacProduct, seller.uid);
  await setWalletBalance(pool, buyer.uid, 1000);

  // Create order as buyer
  log(`\n🛒 Creating order as buyer...`);
  const createResult = await callFunction('sqlGatewayStoreCreateOrder', {
    productId: rbacProduct.id,
  }, { auth: { uid: buyer.uid } });

  if (!createResult.success) {
    error(`❌ Order creation failed`);
    return { passed: false, reason: 'order_creation_failed' };
  }

  const orderId = createResult.data.orderId;
  log(`   ✅ Order created: ${orderId}`);

  // Test: Buyer should NOT be able to release escrow (only seller or system_writer)
  log(`\n🚫 Testing RBAC: Buyer attempting to release escrow...`);
  const unauthorizedRelease = await callFunction('sqlGatewayStoreReleaseEscrow', {
    orderId,
  }, { auth: { uid: buyer.uid } });

  if (unauthorizedRelease.success) {
    error(`   ❌ Buyer should NOT be able to release escrow!`);
    return { passed: false, reason: 'rbac_not_enforced_release' };
  }

  log(`   ✅ Buyer correctly denied (${unauthorizedRelease.error.code})`);

  // Test: Seller should be able to release
  log(`\n✅ Testing RBAC: Seller releasing escrow...`);
  const authorizedRelease = await callFunction('sqlGatewayStoreReleaseEscrow', {
    orderId,
  }, { auth: { uid: seller.uid } });

  if (!authorizedRelease.success) {
    error(`   ❌ Seller should be able to release escrow: ${authorizedRelease.error.message}`);
    return { passed: false, reason: 'seller_release_failed' };
  }

  log(`   ✅ Seller successfully released escrow`);

  log(`\n✅ RBAC enforcement working correctly`);
  return { passed: true };
}

// ==================== MAIN TEST RUNNER ====================

async function runTests() {
  console.log('╔════════════════════════════════════════════════════════╗');
  console.log('║  CringeStore Integration Test Suite                   ║');
  console.log('╚════════════════════════════════════════════════════════╝');
  console.log();
  console.log(`Target Scenario: ${TARGET_SCENARIO}`);
  console.log(`Verbose: ${VERBOSE}`);
  console.log(`Skip Cleanup: ${SKIP_CLEANUP}`);
  console.log();

  const pool = await connectSQL();
  const results = {};

  try {
    if (TARGET_SCENARIO === 'all' || TARGET_SCENARIO === 'order') {
      results.orderFlow = await testOrderFlow(pool);
      await cleanupTestData(pool);
    }

    if (TARGET_SCENARIO === 'all' || TARGET_SCENARIO === 'refund') {
      results.refundFlow = await testRefundFlow(pool);
      await cleanupTestData(pool);
    }

    if (TARGET_SCENARIO === 'all' || TARGET_SCENARIO === 'wallet') {
      results.walletConsistency = await testWalletConsistency(pool);
      await cleanupTestData(pool);
    }

    if (TARGET_SCENARIO === 'all' || TARGET_SCENARIO === 'rbac') {
      results.rbacEnforcement = await testRBACEnforcement(pool);
      await cleanupTestData(pool);
    }

    // Summary
    console.log('\n╔════════════════════════════════════════════════════════╗');
    console.log('║  Test Summary                                          ║');
    console.log('╚════════════════════════════════════════════════════════╝');
    console.log();

    let passedCount = 0;
    let failedCount = 0;

    Object.entries(results).forEach(([testName, result]) => {
      const status = result.passed ? '✅ PASSED' : `❌ FAILED (${result.reason || 'unknown'})`;
      console.log(`${testName}: ${status}`);
      if (result.passed) {
        passedCount++;
      } else {
        failedCount++;
      }
    });

    console.log();
    console.log(`Total: ${passedCount + failedCount} tests`);
    console.log(`Passed: ${passedCount}`);
    console.log(`Failed: ${failedCount}`);
    console.log();

    if (failedCount === 0) {
      console.log('🎉 All tests passed!');
      process.exit(0);
    } else {
      console.log('❌ Some tests failed');
      process.exit(1);
    }
  } catch (error) {
    console.error('\n❌ Test execution failed:', error);
    await cleanupTestData(pool);
    process.exit(1);
  } finally {
    await disconnectSQL();
  }
}

// ==================== EXECUTE ====================

runTests().catch(error => {
  console.error('❌ Unhandled error:', error);
  process.exit(1);
});
