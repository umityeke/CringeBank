# Staging Environment Testing Guide

**Tarih:** 9 Ekim 2025  
**Amaç:** Production deployment öncesi staging environment'ta kapsamlı test

---

## 🎯 Test Objectives

1. ✅ Integration tests passing (all 4 scenarios)
2. ✅ Load testing (100+ concurrent orders)
3. ✅ Performance benchmarking (P95 latency < 500ms)
4. ✅ Wallet consistency validation
5. ✅ Rollback procedure verification

---

## 📋 Prerequisites

### 1. Staging Environment Setup

**Firebase Project:**
```bash
# Switch to staging project
firebase use staging

# Verify current project
firebase projects:list
# Expected: staging project selected
```

**Azure SQL Database (Staging):**
- Separate staging database: `cringebank-staging`
- Connection string configured in Firebase config
- All tables and stored procedures deployed

**Environment Variables:**
```bash
# Set staging SQL config
firebase functions:config:set \
  sql.server="staging-server.database.windows.net" \
  sql.database="cringebank-staging" \
  sql.user="staging-user" \
  sql.password="STAGING_PASSWORD" \
  --project staging

# Verify config
firebase functions:config:get --project staging
```

### 2. Deploy to Staging

```bash
# Deploy all functions to staging
firebase deploy --only functions --project staging

# Verify deployment
firebase functions:list --project staging | grep sqlGateway

# Expected output:
# sqlGatewayStoreCreateOrder
# sqlGatewayStoreReleaseEscrow
# sqlGatewayStoreRefundOrder
# sqlGatewayStoreGetOrder
# sqlGatewayStoreAdjustWallet
# sqlGatewayStoreGetWallet
# dailyWalletConsistencyCheck
# hourlyMetricsCollection
```

### 3. Test User Setup

```bash
cd functions/scripts

# Create test users in staging
node assign_role.js assign test.buyer@staging.cringebank.test user --project staging
node assign_role.js assign test.seller@staging.cringebank.test user --project staging
node assign_role.js assign test.admin@staging.cringebank.test superadmin --project staging

# Verify users created
firebase auth:export users.json --project staging
cat users.json | grep "test\."
```

---

## 🧪 Test Suite

### Test 1: Integration Tests

**Run all integration tests:**

```bash
cd functions/tests

# Set staging environment
export FIREBASE_PROJECT=staging
export SQL_SERVER=staging-server.database.windows.net
export SQL_DATABASE=cringebank-staging
export SQL_USER=staging-user
export SQL_PASSWORD=STAGING_PASSWORD

# Run integration test suite
node store_integration_test.js --verbose

# Expected output:
# ✅ orderFlow: PASSED (create → lock → release → validate)
# ✅ refundFlow: PASSED (create → refund → restore balance)
# ✅ walletConsistency: PASSED (multiple adjustments tracked)
# ✅ rbacEnforcement: PASSED (buyer denied, seller allowed)
#
# Total: 4 tests
# Passed: 4
# Failed: 0
# 🎉 All tests passed!
```

**Success Criteria:**
- ✅ All 4 scenarios pass
- ✅ No SQL errors in logs
- ✅ Wallet balances accurate after each test
- ✅ Test cleanup successful (no orphan data)

---

### Test 2: Load Testing (100+ Concurrent Orders)

**Create load test script:**

```javascript
// functions/tests/load_test_orders.js
const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey-staging.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const functions = admin.functions();

async function createOrderConcurrently(userId, productId, price) {
  try {
    const result = await functions.httpsCallable('sqlGatewayStoreCreateOrder')({
      productId,
      buyerAuthUid: userId,
      priceGold: price,
    });
    
    return { success: true, orderId: result.data.orderId };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function runLoadTest(numOrders = 100) {
  console.log(`🚀 Starting load test: ${numOrders} concurrent orders\n`);
  
  const startTime = Date.now();
  
  // Create test users and products first
  const testUsers = [];
  for (let i = 0; i < 10; i++) {
    testUsers.push(`load_test_user_${i}`);
  }
  
  // Create orders concurrently
  const promises = [];
  for (let i = 0; i < numOrders; i++) {
    const userId = testUsers[i % testUsers.length];
    const productId = `load_test_product_${i}`;
    const price = Math.floor(Math.random() * 1000) + 100;
    
    promises.push(createOrderConcurrently(userId, productId, price));
  }
  
  const results = await Promise.all(promises);
  
  const duration = Date.now() - startTime;
  const successCount = results.filter(r => r.success).length;
  const failureCount = results.filter(r => !r.success).length;
  
  console.log('\n📊 LOAD TEST RESULTS');
  console.log('═'.repeat(50));
  console.log(`Total Orders: ${numOrders}`);
  console.log(`Success: ${successCount} (${(successCount/numOrders*100).toFixed(1)}%)`);
  console.log(`Failures: ${failureCount}`);
  console.log(`Duration: ${duration}ms`);
  console.log(`Avg Time: ${(duration/numOrders).toFixed(2)}ms per order`);
  console.log(`Throughput: ${(numOrders / (duration/1000)).toFixed(2)} orders/sec`);
  console.log('═'.repeat(50));
  
  // Show sample failures
  if (failureCount > 0) {
    console.log('\nSample Failures:');
    results.filter(r => !r.success).slice(0, 5).forEach((r, i) => {
      console.log(`  ${i+1}. ${r.error}`);
    });
  }
  
  return {
    total: numOrders,
    success: successCount,
    failure: failureCount,
    duration,
    avgTime: duration / numOrders,
    throughput: numOrders / (duration / 1000),
  };
}

// Run test
runLoadTest(100).catch(console.error);
```

**Run load test:**

```bash
cd functions/tests
node load_test_orders.js

# Expected output:
# 🚀 Starting load test: 100 concurrent orders
# 
# 📊 LOAD TEST RESULTS
# ══════════════════════════════════════════════════
# Total Orders: 100
# Success: 98 (98.0%)
# Failures: 2
# Duration: 12345ms
# Avg Time: 123.45ms per order
# Throughput: 8.10 orders/sec
# ══════════════════════════════════════════════════
```

**Success Criteria:**
- ✅ >95% success rate
- ✅ Average time < 500ms per order
- ✅ Throughput > 5 orders/sec
- ✅ No database deadlocks
- ✅ Wallet balances remain consistent

---

### Test 3: Performance Benchmarking

**Query latency measurement:**

```sql
-- Connect to staging SQL database
sqlcmd -S staging-server.database.windows.net -d cringebank-staging -U staging-user -P PASSWORD

-- Measure stored procedure performance
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

-- Test sp_Store_CreateOrderAndLockEscrow
EXEC sp_Store_CreateOrderAndLockEscrow
  @OrderPublicId = 'perf_test_order_001',
  @ProductId = 'test_product',
  @BuyerAuthUid = 'test_buyer',
  @PriceGold = 500;

-- Expected: CPU time < 100ms, elapsed time < 200ms

-- Test sp_Store_ReleaseEscrow  
EXEC sp_Store_ReleaseEscrow
  @OrderPublicId = 'perf_test_order_001',
  @ActorAuthUid = 'test_seller';

-- Expected: CPU time < 50ms, elapsed time < 150ms

-- Test sp_Store_GetOrder
EXEC sp_Store_GetOrder
  @OrderPublicId = 'perf_test_order_001';

-- Expected: CPU time < 20ms, elapsed time < 50ms
```

**Cloud Functions latency:**

```bash
# Test callable latency
cd functions/tests

node -e "
const admin = require('firebase-admin');
admin.initializeApp();

async function measureLatency() {
  const iterations = 50;
  const times = [];
  
  for (let i = 0; i < iterations; i++) {
    const start = Date.now();
    try {
      await admin.functions().httpsCallable('sqlGatewayStoreGetWallet')({
        targetAuthUid: 'test_buyer'
      });
      times.push(Date.now() - start);
    } catch (e) {
      console.error('Error:', e.message);
    }
  }
  
  times.sort((a, b) => a - b);
  const p50 = times[Math.floor(times.length * 0.5)];
  const p95 = times[Math.floor(times.length * 0.95)];
  const p99 = times[Math.floor(times.length * 0.99)];
  
  console.log('Latency Benchmark (sqlGatewayStoreGetWallet):');
  console.log('  P50:', p50 + 'ms');
  console.log('  P95:', p95 + 'ms');
  console.log('  P99:', p99 + 'ms');
  console.log('  Min:', Math.min(...times) + 'ms');
  console.log('  Max:', Math.max(...times) + 'ms');
}

measureLatency();
"
```

**Success Criteria:**
- ✅ SQL stored procedures: P95 < 200ms
- ✅ Cloud Functions callables: P95 < 500ms
- ✅ No timeout errors (60s limit)
- ✅ Consistent performance across iterations

---

### Test 4: Wallet Consistency Validation

```bash
cd functions/scripts

# Run wallet consistency check
node validate_wallet_consistency.js --verbose

# Expected output:
# 🔍 Wallet Consistency Validation
# ==================================================
# Mode: CHECK ONLY
# Verbose: true
# ==================================================
# ✅ SQL connected
# 
# 📦 Firestore: 45 wallets loaded
# 💾 SQL: 45 wallets loaded
# 
# 🔍 Comparing wallets...
# 
# ✅ user_1: Consistent (1000 gold)
# ✅ user_2: Consistent (500 gold)
# ...
# 
# ==================================================
# 📊 VALIDATION SUMMARY
# ==================================================
# Total Checked: 45
# Inconsistencies: 0
# Status: CONSISTENT
# ==================================================
```

**Success Criteria:**
- ✅ Zero inconsistencies
- ✅ All wallets matched between Firestore and SQL
- ✅ No negative balances
- ✅ Total gold balance matches expected value

---

### Test 5: Rollback Procedure Verification

**Test rollback with dummy data:**

```bash
cd functions/scripts

# Create test data
echo "Creating test orders for rollback test..."
node -e "
const admin = require('firebase-admin');
admin.initializeApp();

async function createTestOrders() {
  const db = admin.firestore();
  const batch = db.batch();
  
  for (let i = 0; i < 5; i++) {
    const ref = db.collection('store_orders').doc('rollback_test_' + i);
    batch.set(ref, {
      orderId: 'rollback_test_' + i,
      buyerUid: 'test_buyer',
      productId: 'test_product',
      price: 100,
      status: 'PENDING',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  
  await batch.commit();
  console.log('5 test orders created');
}

createTestOrders();
"

# Run migration
node migrate_firestore_to_sql.js --collection store_orders

# Verify migration succeeded
# Then test rollback

node migrate_firestore_to_sql.js --rollback
# CANCEL within 10 seconds (Ctrl+C)

# Verify rollback
echo "Testing actual rollback (will delete SQL data)..."
# Only run if you're sure!
# node migrate_firestore_to_sql.js --rollback
# (press Enter after 10 seconds)

# Verify SQL data deleted
sqlcmd -S staging-server... -Q "SELECT COUNT(*) FROM StoreOrders WHERE OrderPublicId LIKE 'rollback_test_%'"
# Expected: 0
```

**Success Criteria:**
- ✅ Rollback script runs without errors
- ✅ SQL data deleted completely
- ✅ Firestore data remains intact
- ✅ 10-second cancellation window works

---

## 📊 Test Results Template

```markdown
# Staging Test Results - [DATE]

## Test 1: Integration Tests
- ✅ orderFlow: PASSED
- ✅ refundFlow: PASSED
- ✅ walletConsistency: PASSED
- ✅ rbacEnforcement: PASSED

## Test 2: Load Testing
- Total Orders: 100
- Success Rate: 98%
- Avg Time: 145ms
- Throughput: 7.2 orders/sec
- Status: ✅ PASSED

## Test 3: Performance Benchmarking
- SQL P95 Latency: 180ms ✅
- Cloud Functions P95: 420ms ✅
- No timeouts: ✅

## Test 4: Wallet Consistency
- Total Wallets: 45
- Inconsistencies: 0 ✅
- Negative Balances: 0 ✅

## Test 5: Rollback Verification
- Rollback Script: ✅ WORKS
- Data Deletion: ✅ COMPLETE
- Firestore Intact: ✅ CONFIRMED

## Overall Status: ✅ ALL TESTS PASSED

Ready for production canary deployment.
```

---

## ✅ Sign-off Checklist

- [ ] All integration tests passing
- [ ] Load test >95% success rate
- [ ] Performance within SLA (<500ms P95)
- [ ] Wallet consistency validated
- [ ] Rollback procedure tested
- [ ] No SQL errors in logs
- [ ] No Cloud Functions errors
- [ ] Test results documented
- [ ] Staging cleanup completed

**Approved by:** _________________  
**Date:** _________________

---

**Sonraki Adım:** Production Readiness (Item #3)
