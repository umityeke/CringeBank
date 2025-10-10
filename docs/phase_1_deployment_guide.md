# Faz 1 Deployment Guide

**Son Güncelleme:** 9 Ekim 2025  
**Hedef:** Production deployment of SQL-backed CringeStore financial modules

---

## 🎯 Deployment Özeti

Bu guide, CringeStore Faz 1 (Finansal Modüller) SQL migration'ını production'a deploy etmek için adım adım talimatlar içerir.

---

## 📋 Prerequisites

### 1. Azure SQL Server

✅ **Database Hazır:**
- Connection string mevcut: `SQL_SERVER`, `SQL_DATABASE`, `SQL_USER`, `SQL_PASSWORD`
- Network access configured (Azure Functions IP whitelist)
- TLS/SSL enabled

✅ **Tables Created:**
```sql
StoreProducts
StoreOrders
StoreEscrows
StoreWallets
StoreWalletLedger
```

### 2. Firebase Project

✅ **Environment Variables:**
```bash
SQL_SERVER=your-server.database.windows.net
SQL_DATABASE=your-database
SQL_USER=your-user
SQL_PASSWORD=your-password
SQL_GATEWAY_REGION=europe-west1
```

Set via Firebase CLI:
```bash
firebase functions:config:set \
  sql.server="your-server.database.windows.net" \
  sql.database="your-database" \
  sql.user="your-user" \
  sql.password="your-password"
```

✅ **RBAC System:**
- Custom claims active
- Roles: `user`, `system_writer`, `superadmin`
- Role assignment script: `functions/scripts/assign_role.js`

### 3. Development Environment

✅ **Node.js Dependencies:**
```bash
cd functions
npm install
```

✅ **Flutter Dependencies:**
```bash
flutter pub get
```

---

## 🚀 Deployment Steps

### Phase 1: SQL Deployment (Staging)

#### 1.1 Deploy Stored Procedures

```bash
# Connect to Azure SQL Server
sqlcmd -S your-server.database.windows.net -d your-database -U your-user -P your-password

# Deploy migration procedures
:r backend/scripts/stored_procedures/sp_Migration_Upserts.sql
GO

# Deploy financial procedures
:r backend/scripts/stored_procedures/sp_Store_CreateOrderAndLockEscrow.sql
GO
:r backend/scripts/stored_procedures/sp_Store_ReleaseEscrow.sql
GO
:r backend/scripts/stored_procedures/sp_Store_RefundOrder.sql
GO
:r backend/scripts/stored_procedures/sp_Store_GetOrder.sql
GO
:r backend/scripts/stored_procedures/sp_Store_AdjustWalletBalance.sql
GO
```

**Alternatif (Azure Data Studio):**
- Open each `.sql` file
- Connect to database
- Execute (F5)

#### 1.2 Verify Stored Procedures

```sql
-- List all store procedures
SELECT name, create_date, modify_date
FROM sys.objects
WHERE type = 'P' AND name LIKE 'sp_Store_%' OR name LIKE 'sp_Migration_%'
ORDER BY name;

-- Expected output:
-- sp_Migration_UpsertEscrow
-- sp_Migration_UpsertOrder
-- sp_Migration_UpsertProduct
-- sp_Migration_UpsertWallet
-- sp_Store_AdjustWalletBalance
-- sp_Store_CreateOrderAndLockEscrow
-- sp_Store_GetOrder
-- sp_Store_RefundOrder
-- sp_Store_ReleaseEscrow
```

#### 1.3 Grant Permissions

```sql
-- Grant execute to SQL Gateway service account
GRANT EXECUTE ON dbo.sp_Store_CreateOrderAndLockEscrow TO your_service_account;
GRANT EXECUTE ON dbo.sp_Store_ReleaseEscrow TO your_service_account;
GRANT EXECUTE ON dbo.sp_Store_RefundOrder TO your_service_account;
GRANT EXECUTE ON dbo.sp_Store_GetOrder TO your_service_account;
GRANT EXECUTE ON dbo.sp_Store_AdjustWalletBalance TO your_service_account;
GRANT EXECUTE ON dbo.sp_Store_GetWallet TO your_service_account;

-- Grant migration procedures to superadmin only
GRANT EXECUTE ON dbo.sp_Migration_UpsertProduct TO superadmin;
GRANT EXECUTE ON dbo.sp_Migration_UpsertOrder TO superadmin;
GRANT EXECUTE ON dbo.sp_Migration_UpsertEscrow TO superadmin;
GRANT EXECUTE ON dbo.sp_Migration_UpsertWallet TO superadmin;
```

---

### Phase 2: Data Migration (Staging)

#### 2.1 Dry Run Migration

```bash
cd functions/scripts
node migrate_firestore_to_sql.js --dry-run
```

**Expected Output:**
```
Found X products
Found Y orders
Found Z escrows
Found W wallets

[DRY RUN] Would migrate product: ...
[DRY RUN] Would migrate order: ...
...

Migration simulation complete: N records migrated, 0 errors
```

#### 2.2 Execute Migration

```bash
# Backup Firestore first!
# Export collections via Firebase Console or gcloud

# Run migration
node migrate_firestore_to_sql.js

# Review output
# Verify: "Migration complete: X records migrated, 0 errors"
```

#### 2.3 Validate Migration

```bash
# Run with validation (default)
node migrate_firestore_to_sql.js

# Check validation output:
# ✅ Product count: X
# ✅ Order count: Y
# ✅ Escrow count: Z
# ✅ Wallet count: W
# ✅ Total wallet balance: XXX gold
# ✅ Orders with escrows: Y
```

**Manual Validation Queries:**
```sql
-- Check total records
SELECT 
  (SELECT COUNT(*) FROM StoreProducts) AS Products,
  (SELECT COUNT(*) FROM StoreOrders) AS Orders,
  (SELECT COUNT(*) FROM StoreEscrows) AS Escrows,
  (SELECT COUNT(*) FROM StoreWallets) AS Wallets;

-- Verify wallet balance integrity
SELECT SUM(GoldBalance) AS TotalBalance, SUM(PendingGold) AS TotalPending
FROM StoreWallets;

-- Check order-escrow relationship
SELECT COUNT(*) AS OrphanOrders
FROM StoreOrders o
LEFT JOIN StoreEscrows e ON o.OrderPublicId = e.OrderPublicId
WHERE e.EscrowPublicId IS NULL;
-- Expected: 0 (all orders should have escrows)
```

---

### Phase 3: Cloud Functions Deployment (Staging)

#### 3.1 Deploy Functions

```bash
# Staging deployment
firebase use staging
firebase deploy --only functions:sqlGatewayStoreRefundOrder,functions:sqlGatewayStoreGetOrder

# Full SQL Gateway deployment
firebase deploy --only functions
```

#### 3.2 Verify Callables

```bash
# List deployed functions
firebase functions:list | grep sqlGateway

# Expected:
# sqlGatewayStoreCreateOrder
# sqlGatewayStoreReleaseEscrow
# sqlGatewayStoreRefundEscrow
# sqlGatewayStoreRefundOrder  <-- NEW
# sqlGatewayStoreGetOrder     <-- NEW
# sqlGatewayStoreAdjustWallet
# sqlGatewayStoreGetWallet
```

#### 3.3 Test Callables

**Using Firebase Emulator:**
```bash
firebase emulators:start --only functions

# In another terminal:
cd functions/tests
node store_integration_test.js --scenario order --verbose
```

**Manual Test (curl):**
```bash
# Get Firebase ID token first
TOKEN=$(firebase auth:export --format=json | jq -r '.users[0].customAttributes')

# Call function
curl -X POST https://europe-west1-your-project.cloudfunctions.net/sqlGatewayStoreGetOrder \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"orderId":"test_order_123"}'
```

---

### Phase 4: Integration Testing (Staging)

#### 4.1 Run Test Suite

```bash
cd functions/tests

# Run all scenarios
node store_integration_test.js --verbose

# Expected output:
# ✅ orderFlow: PASSED
# ✅ refundFlow: PASSED
# ✅ walletConsistency: PASSED
# ✅ rbacEnforcement: PASSED
#
# Total: 4 tests
# Passed: 4
# Failed: 0
# 🎉 All tests passed!
```

#### 4.2 Manual Testing

**Create Test Users:**
```bash
cd functions/scripts
node assign_role.js assign test.buyer@cringebank.test user
node assign_role.js assign test.seller@cringebank.test user
```

**Test Order Flow:**
1. Login as buyer in Flutter app (staging build)
2. Navigate to CringeStore
3. Purchase a test product
4. Verify wallet debit
5. Login as seller
6. Release escrow
7. Verify seller wallet credit
8. Check SQL database for order/escrow records

---

### Phase 5: Flutter App Deployment (Staging)

#### 5.1 Build with Feature Flag

```bash
# Enable SQL Gateway
flutter build windows --dart-define=USE_SQL_ESCROW_GATEWAY=true

# Or for Android
flutter build apk --dart-define=USE_SQL_ESCROW_GATEWAY=true
```

#### 5.2 Staging Test

- Install app on test device
- Create order
- Monitor Firebase Console logs
- Verify SQL callable invocations
- Check wallet consistency

---

### Phase 6: Production Deployment (Canary Rollout)

#### 6.1 Deploy to Production

```bash
# Switch to production project
firebase use production

# Deploy Cloud Functions
firebase deploy --only functions

# Verify deployment
firebase functions:list | grep sqlGateway
```

#### 6.2 Canary Rollout (5%)

**Option 1: Client-side Feature Flag**

Update `lib/utils/store_feature_flags.dart`:
```dart
static const bool useSqlEscrowGateway = bool.fromEnvironment(
  'USE_SQL_ESCROW_GATEWAY',
  defaultValue: false, // Start with false
);
```

Deploy app with flag disabled, then enable for 5% via remote config:
```json
{
  "use_sql_escrow_gateway": {
    "defaultValue": { "value": false },
    "conditionalValues": {
      "percent_5": {
        "value": true
      }
    }
  }
}
```

**Option 2: Server-side Rollout**

Keep `defaultValue: true` in code, but add server-side check in Cloud Functions:
```javascript
// In sql_gateway/index.js
const ROLLOUT_PERCENTAGE = 5;

function shouldUseSqlGateway(userId) {
  const hash = crypto.createHash('md5').update(userId).digest('hex');
  const bucket = parseInt(hash.substring(0, 8), 16) % 100;
  return bucket < ROLLOUT_PERCENTAGE;
}
```

#### 6.3 Monitor (24-48 hours)

**Firebase Console:**
- Functions → Logs
- Filter: `sqlGatewayStore*`
- Check error rate (<1%)
- Check latency (P95 <500ms)

**SQL Server:**
```sql
-- Query performance
SELECT 
  OBJECT_NAME(object_id) AS ProcedureName,
  execution_count,
  total_elapsed_time / execution_count AS avg_elapsed_time_ms
FROM sys.dm_exec_procedure_stats
WHERE OBJECT_NAME(object_id) LIKE 'sp_Store_%'
ORDER BY execution_count DESC;

-- Wallet balance integrity
SELECT COUNT(*) AS NegativeBalances
FROM StoreWallets
WHERE GoldBalance < 0;
-- Expected: 0
```

**Application Metrics:**
- User-reported errors (support tickets)
- Order completion rate
- Wallet inconsistency reports

#### 6.4 Gradual Rollout

If 5% successful after 48 hours:
- Increase to 25%
- Monitor for 48 hours
- Increase to 50%
- Monitor for 48 hours
- Increase to 100%

---

### Phase 7: Legacy Cleanup (After 100% Rollout)

#### 7.1 Disable Legacy Functions (1 week after 100%)

```javascript
// In functions/index.js
// Comment out or remove:
// exports.escrowLock = functions.region('europe-west1').https.onCall(async (data, context) => { ... });
// exports.escrowRelease = functions.region('europe-west1').https.onCall(async (data, context) => { ... });
// exports.escrowRefund = functions.region('europe-west1').https.onCall(async (data, context) => { ... });
```

Deploy:
```bash
firebase deploy --only functions
```

#### 7.2 Archive Firestore Collections (2 weeks after 100%)

**Backup:**
```bash
gcloud firestore export gs://your-bucket/firestore-backup-$(date +%Y%m%d)
```

**Optional Cleanup:**
```javascript
// Script to delete old Firestore data (CAREFUL!)
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function cleanupFirestore() {
  const collections = ['store_products', 'store_orders', 'store_escrows', 'store_wallets'];
  
  for (const collectionName of collections) {
    const snapshot = await db.collection(collectionName).get();
    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    console.log(`Deleted ${snapshot.size} docs from ${collectionName}`);
  }
}

// Run only after confirmation!
// cleanupFirestore();
```

---

## 🔥 Rollback Plan

### If Critical Issues Detected:

#### 1. Immediate Rollback (Client-side)

**Update remote config:**
```json
{
  "use_sql_escrow_gateway": {
    "defaultValue": { "value": false }
  }
}
```

Publish immediately. Users will revert to Firestore on next app launch.

#### 2. Data Inconsistency Detected

**Run validation queries:**
```sql
-- Find negative balances
SELECT AuthUid, GoldBalance, PendingGold
FROM StoreWallets
WHERE GoldBalance < 0;

-- Find orphan escrows
SELECT e.*
FROM StoreEscrows e
LEFT JOIN StoreOrders o ON e.OrderPublicId = o.OrderPublicId
WHERE o.OrderPublicId IS NULL;
```

**Manual reconciliation:**
```sql
-- Adjust wallet balance
EXEC dbo.sp_Store_AdjustWalletBalance
  @TargetAuthUid = 'affected_user_uid',
  @ActorAuthUid = 'admin_uid',
  @AmountDelta = 100,  -- Correction amount
  @Reason = 'Manual reconciliation - rollback correction',
  @MetadataJson = '{"rollback": true, "ticket": "SUPPORT-123"}',
  @IsSystemOverride = 1;
```

#### 3. Database Rollback (EXTREME)

```bash
# Use migration script rollback
cd functions/scripts
node migrate_firestore_to_sql.js --rollback

# WARNING: Deletes ALL store data from SQL!
# Press Ctrl+C within 10 seconds to cancel
```

---

## 📊 Success Metrics

### Deployment Successful If:

✅ **Error Rate:** <1% across all SQL callables  
✅ **Latency:** P95 <500ms for order creation  
✅ **Wallet Consistency:** 0 negative balances  
✅ **Order Completion Rate:** ≥99%  
✅ **User Reports:** <5 support tickets related to store issues  

### Monitor for 2 Weeks:

- Daily validation queries
- Weekly wallet balance audit
- User feedback review
- Performance metrics trending

---

## 📞 Support Contacts

**SQL Server Issues:**
- Azure Portal → SQL Database → Query Performance Insight
- Contact: DBA team

**Cloud Functions Issues:**
- Firebase Console → Functions → Logs
- Contact: Backend team

**App Issues:**
- Firebase Console → Crashlytics
- Contact: Mobile team

---

## ✅ Post-Deployment Checklist

- [ ] SQL procedures deployed and verified
- [ ] Data migration completed (0 errors)
- [ ] Validation queries passing
- [ ] Cloud Functions deployed
- [ ] Integration tests passing (4/4)
- [ ] Canary rollout started (5%)
- [ ] Monitoring dashboards active
- [ ] Rollback plan documented
- [ ] Team notified of deployment

---

**Deployment Owner:** [Your Name]  
**Approval:** [Manager Name]  
**Date:** [Deployment Date]
