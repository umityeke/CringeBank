#!/usr/bin/env node

/**
 * CringeStore Firestore → SQL Migration Script
 * 
 * Migrates store data from Firestore collections to SQL Server:
 * - store_products → StoreProducts table
 * - store_orders → StoreOrders table  
 * - store_escrows → StoreEscrows table
 * - store_wallets → StoreWallets table
 * 
 * Usage:
 *   node migrate_firestore_to_sql.js [options]
 * 
 * Options:
 *   --dry-run          Validate data without writing to SQL
 *   --collection NAME  Migrate only specified collection (products|orders|escrows|wallets)
 *   --batch-size N     Process N documents per batch (default: 50)
 *   --skip-validation  Skip post-migration validation queries
 *   --rollback         Attempt to rollback migration (delete migrated records)
 * 
 * Prerequisites:
 *   - Firebase Admin SDK credentials
 *   - SQL Server connection configured in environment
 *   - RBAC: Requires system_writer role or superadmin
 * 
 * Example:
 *   # Dry run to preview changes
 *   node migrate_firestore_to_sql.js --dry-run
 * 
 *   # Migrate only products
 *   node migrate_firestore_to_sql.js --collection products
 * 
 *   # Full migration with validation
 *   node migrate_firestore_to_sql.js
 */

const admin = require('firebase-admin');
const mssql = require('mssql');
const fs = require('fs');
const path = require('path');

// ==================== CONFIGURATION ====================

const BATCH_SIZE = parseInt(process.env.MIGRATION_BATCH_SIZE || '50', 10);
const DRY_RUN = process.argv.includes('--dry-run');
const SKIP_VALIDATION = process.argv.includes('--skip-validation');
const ROLLBACK_MODE = process.argv.includes('--rollback');

const targetCollectionArg = process.argv.find(arg => arg.startsWith('--collection='));
const TARGET_COLLECTION = targetCollectionArg
  ? targetCollectionArg.split('=')[1].trim()
  : null;

const batchSizeArg = process.argv.find(arg => arg.startsWith('--batch-size='));
const EFFECTIVE_BATCH_SIZE = batchSizeArg
  ? parseInt(batchSizeArg.split('=')[1], 10) || BATCH_SIZE
  : BATCH_SIZE;

// ==================== FIREBASE INITIALIZATION ====================

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, '../../service-account-key.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error(`❌ Service account key not found: ${serviceAccountPath}`);
  console.error('   Set GOOGLE_APPLICATION_CREDENTIALS environment variable or place key at default path.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccountPath),
});

const db = admin.firestore();

// ==================== SQL SERVER CONNECTION ====================

const SQL_ENCRYPT = (() => {
  const value = (process.env.SQL_ENCRYPT || '').toLowerCase();
  if (value === '0' || value === 'false') {
    return false;
  }
  if (value === '1' || value === 'true') {
    return true;
  }
  return true;
})();

const SQL_TRUST_SERVER_CERTIFICATE = (() => {
  const value = (process.env.SQL_TRUST_SERVER_CERTIFICATE || '').toLowerCase();
  return value === '1' || value === 'true';
})();

const sqlConfig = {
  user: process.env.SQL_USER,
  password: process.env.SQL_PASSWORD,
  server: process.env.SQL_SERVER,
  database: process.env.SQL_DATABASE,
  options: {
    encrypt: SQL_ENCRYPT,
    trustServerCertificate: SQL_TRUST_SERVER_CERTIFICATE,
    enableArithAbort: true,
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
};

if (!sqlConfig.user || !sqlConfig.password || !sqlConfig.server || !sqlConfig.database) {
  console.error('❌ SQL Server connection environment variables not set:');
  console.error('   Required: SQL_USER, SQL_PASSWORD, SQL_SERVER, SQL_DATABASE');
  process.exit(1);
}

let sqlPool = null;

async function connectSQL() {
  if (!sqlPool) {
    console.log('🔌 Connecting to SQL Server...');
    sqlPool = await mssql.connect(sqlConfig);
    console.log('✅ SQL Server connected');
  }
  return sqlPool;
}

async function disconnectSQL() {
  if (sqlPool) {
    await sqlPool.close();
    sqlPool = null;
    console.log('🔌 SQL Server connection closed');
  }
}

// ==================== UTILITY FUNCTIONS ====================

function toSafeString(value, maxLength = null) {
  if (value === null || value === undefined) {
    return null;
  }
  const str = value.toString().trim();
  if (maxLength && str.length > maxLength) {
    return str.substring(0, maxLength);
  }
  return str || null;
}

function toSafeInt(value) {
  const parsed = parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

function toSafeDecimal(value) {
  const parsed = parseFloat(value);
  return Number.isFinite(parsed) ? parsed : 0.0;
}

function toSqlDateTime(timestamp) {
  if (!timestamp) {
    return null;
  }
  try {
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toISOString();
  } catch (error) {
    return null;
  }
}

function toJsonString(obj) {
  if (!obj) {
    return null;
  }
  try {
    return JSON.stringify(obj);
  } catch (error) {
    return null;
  }
}

// ==================== MIGRATION HANDLERS ====================

async function migrateProducts(pool, dryRun = false) {
  console.log('\n📦 Migrating store_products...');
  const snapshot = await db.collection('store_products').get();
  console.log(`   Found ${snapshot.size} products`);

  if (snapshot.empty) {
    console.log('   ℹ️  No products to migrate');
    return { total: 0, migrated: 0, errors: 0 };
  }

  let migrated = 0;
  let errors = 0;
  const batches = [];
  let currentBatch = [];

  for (const doc of snapshot.docs) {
    currentBatch.push(doc);
    if (currentBatch.length >= EFFECTIVE_BATCH_SIZE) {
      batches.push(currentBatch);
      currentBatch = [];
    }
  }
  if (currentBatch.length > 0) {
    batches.push(currentBatch);
  }

  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];
    console.log(`   Processing batch ${i + 1}/${batches.length} (${batch.length} products)...`);

    for (const doc of batch) {
      const data = doc.data();
      const productId = doc.id;

      try {
        if (dryRun) {
          console.log(`   [DRY RUN] Would migrate product: ${productId} - ${data.title}`);
          migrated++;
          continue;
        }

        const request = pool.request();
        request.input('ProductId', mssql.NVarChar(64), productId);
        request.input('Title', mssql.NVarChar(255), toSafeString(data.title, 255));
        request.input('Description', mssql.NVarChar(mssql.MAX), toSafeString(data.desc));
        request.input('PriceGold', mssql.Int, toSafeInt(data.priceGold));
        request.input('ImagesJson', mssql.NVarChar(mssql.MAX), toJsonString(data.images || []));
        request.input('Category', mssql.NVarChar(64), toSafeString(data.category, 64));
        request.input('Condition', mssql.NVarChar(32), toSafeString(data.condition, 32));
        request.input('Status', mssql.NVarChar(32), toSafeString(data.status, 32) || 'ACTIVE');
        request.input('SellerAuthUid', mssql.NVarChar(64), toSafeString(data.sellerId || data.sellerAuthUid, 64));
        request.input('VendorId', mssql.NVarChar(64), toSafeString(data.vendorId, 64));
        request.input('SellerType', mssql.NVarChar(32), toSafeString(data.sellerType, 32) || 'P2P');
        request.input('QrUid', mssql.NVarChar(64), toSafeString(data.qrUid, 64));
        request.input('QrBound', mssql.Bit, data.qrBound ? 1 : 0);
        request.input('ReservedBy', mssql.NVarChar(64), toSafeString(data.reservedBy, 64));
        request.input('ReservedAt', mssql.DateTime2, toSqlDateTime(data.reservedAt));
        request.input('SharedEntryId', mssql.NVarChar(64), toSafeString(data.sharedEntryId, 64));
        request.input('SharedByAuthUid', mssql.NVarChar(64), toSafeString(data.sharedByAuthUid, 64));
        request.input('SharedAt', mssql.DateTime2, toSqlDateTime(data.sharedAt));
        request.input('CreatedAt', mssql.DateTime2, toSqlDateTime(data.createdAt));
        request.input('UpdatedAt', mssql.DateTime2, toSqlDateTime(data.updatedAt));

        await request.execute('dbo.sp_Migration_UpsertProduct');
        migrated++;
        console.log(`   ✅ Migrated: ${productId} - ${data.title}`);
      } catch (error) {
        errors++;
        console.error(`   ❌ Error migrating product ${productId}:`, error.message);
      }
    }
  }

  console.log(`   📦 Products migration complete: ${migrated}/${snapshot.size} migrated, ${errors} errors`);
  return { total: snapshot.size, migrated, errors };
}

async function migrateOrders(pool, dryRun = false) {
  console.log('\n📋 Migrating store_orders...');
  const snapshot = await db.collection('store_orders').get();
  console.log(`   Found ${snapshot.size} orders`);

  if (snapshot.empty) {
    console.log('   ℹ️  No orders to migrate');
    return { total: 0, migrated: 0, errors: 0 };
  }

  let migrated = 0;
  let errors = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const orderId = data.id || doc.id;

    try {
      if (dryRun) {
        console.log(`   [DRY RUN] Would migrate order: ${orderId}`);
        migrated++;
        continue;
      }

      const request = pool.request();
      request.input('OrderPublicId', mssql.NVarChar(64), orderId);
      request.input('ProductId', mssql.NVarChar(64), toSafeString(data.productId, 64));
      request.input('BuyerAuthUid', mssql.NVarChar(64), toSafeString(data.buyerId || data.buyerAuthUid, 64));
      request.input('SellerAuthUid', mssql.NVarChar(64), toSafeString(data.sellerId || data.sellerAuthUid, 64));
      request.input('VendorId', mssql.NVarChar(64), toSafeString(data.vendorId, 64));
      request.input('SellerType', mssql.NVarChar(32), toSafeString(data.sellerType, 32));
      request.input('ItemPriceGold', mssql.Int, toSafeInt(data.itemPriceGold || data.priceGold));
      request.input('CommissionGold', mssql.Int, toSafeInt(data.commissionGold || data.commission));
      request.input('TotalGold', mssql.Int, toSafeInt(data.totalGold || data.total));
      request.input('Status', mssql.NVarChar(32), toSafeString(data.status, 32) || 'PENDING');
      request.input('PaymentStatus', mssql.NVarChar(32), toSafeString(data.paymentStatus, 32));
      request.input('TimelineJson', mssql.NVarChar(mssql.MAX), toJsonString(data.timeline));
      request.input('CreatedAt', mssql.DateTime2, toSqlDateTime(data.createdAt));
      request.input('UpdatedAt', mssql.DateTime2, toSqlDateTime(data.updatedAt));
      request.input('DeliveredAt', mssql.DateTime2, toSqlDateTime(data.deliveredAt));
      request.input('ReleasedAt', mssql.DateTime2, toSqlDateTime(data.releasedAt));
      request.input('RefundedAt', mssql.DateTime2, toSqlDateTime(data.refundedAt));
      request.input('DisputedAt', mssql.DateTime2, toSqlDateTime(data.disputedAt));
      request.input('CompletedAt', mssql.DateTime2, toSqlDateTime(data.completedAt));
      request.input('CanceledAt', mssql.DateTime2, toSqlDateTime(data.canceledAt || data.cancelledAt));

      await request.execute('dbo.sp_Migration_UpsertOrder');
      migrated++;
      console.log(`   ✅ Migrated: ${orderId}`);
    } catch (error) {
      errors++;
      console.error(`   ❌ Error migrating order ${orderId}:`, error.message);
    }
  }

  console.log(`   📋 Orders migration complete: ${migrated}/${snapshot.size} migrated, ${errors} errors`);
  return { total: snapshot.size, migrated, errors };
}

async function migrateEscrows(pool, dryRun = false) {
  console.log('\n🔒 Migrating store_escrows...');
  const snapshot = await db.collection('store_escrows').get();
  console.log(`   Found ${snapshot.size} escrows`);

  if (snapshot.empty) {
    console.log('   ℹ️  No escrows to migrate');
    return { total: 0, migrated: 0, errors: 0 };
  }

  let migrated = 0;
  let errors = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const escrowId = doc.id;

    try {
      if (dryRun) {
        console.log(`   [DRY RUN] Would migrate escrow: ${escrowId} for order ${data.orderId}`);
        migrated++;
        continue;
      }

      const request = pool.request();
      request.input('EscrowPublicId', mssql.NVarChar(64), escrowId);
      request.input('OrderPublicId', mssql.NVarChar(64), toSafeString(data.orderId, 64));
      request.input('BuyerAuthUid', mssql.NVarChar(64), toSafeString(data.buyerId || data.buyerAuthUid, 64));
      request.input('SellerAuthUid', mssql.NVarChar(64), toSafeString(data.sellerId || data.sellerAuthUid, 64));
  request.input('EscrowState', mssql.NVarChar(32), toSafeString(data.state, 32) || 'LOCKED');
      request.input('LockedAmountGold', mssql.Int, toSafeInt(data.lockedAmountGold || data.amount));
      request.input('ReleasedAmountGold', mssql.Int, toSafeInt(data.releasedAmountGold));
      request.input('RefundedAmountGold', mssql.Int, toSafeInt(data.refundedAmountGold));
      request.input('LockedAt', mssql.DateTime2, toSqlDateTime(data.lockedAt || data.createdAt));
      request.input('ReleasedAt', mssql.DateTime2, toSqlDateTime(data.releasedAt));
      request.input('RefundedAt', mssql.DateTime2, toSqlDateTime(data.refundedAt));

      await request.execute('dbo.sp_Migration_UpsertEscrow');
      migrated++;
      console.log(`   ✅ Migrated: ${escrowId} (order: ${data.orderId})`);
    } catch (error) {
      errors++;
      console.error(`   ❌ Error migrating escrow ${escrowId}:`, error.message);
    }
  }

  console.log(`   🔒 Escrows migration complete: ${migrated}/${snapshot.size} migrated, ${errors} errors`);
  return { total: snapshot.size, migrated, errors };
}

async function migrateWallets(pool, dryRun = false) {
  console.log('\n💰 Migrating store_wallets...');
  const snapshot = await db.collection('store_wallets').get();
  console.log(`   Found ${snapshot.size} wallets`);

  if (snapshot.empty) {
    console.log('   ℹ️  No wallets to migrate');
    return { total: 0, migrated: 0, errors: 0 };
  }

  let migrated = 0;
  let errors = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const authUid = data.userId || data.authUid || doc.id;

    try {
      if (dryRun) {
        console.log(`   [DRY RUN] Would migrate wallet for user: ${authUid} (balance: ${data.goldBalance || 0})`);
        migrated++;
        continue;
      }

      const request = pool.request();
      request.input('AuthUid', mssql.NVarChar(64), authUid);
      request.input('GoldBalance', mssql.Int, toSafeInt(data.goldBalance));
      request.input('PendingGold', mssql.Int, toSafeInt(data.pendingGold));

      await request.execute('dbo.sp_Migration_UpsertWallet');
      migrated++;
      console.log(`   ✅ Migrated: ${authUid} (balance: ${data.goldBalance || 0})`);
    } catch (error) {
      errors++;
      console.error(`   ❌ Error migrating wallet ${authUid}:`, error.message);
    }
  }

  console.log(`   💰 Wallets migration complete: ${migrated}/${snapshot.size} migrated, ${errors} errors`);
  return { total: snapshot.size, migrated, errors };
}

// ==================== VALIDATION ====================

async function validateMigration(pool) {
  console.log('\n🔍 Running validation queries...');

  const validations = [
    {
      name: 'Product count',
      query: 'SELECT COUNT(*) AS cnt FROM StoreProducts',
    },
    {
      name: 'Order count',
      query: 'SELECT COUNT(*) AS cnt FROM StoreOrders',
    },
    {
      name: 'Escrow count',
      query: 'SELECT COUNT(*) AS cnt FROM StoreEscrows',
    },
    {
      name: 'Wallet count',
      query: 'SELECT COUNT(*) AS cnt FROM StoreWallets',
    },
    {
      name: 'Total wallet balance',
      query: 'SELECT SUM(GoldBalance) AS total FROM StoreWallets',
    },
    {
      name: 'Orders with escrows',
      query: `
        SELECT COUNT(*) AS cnt 
        FROM StoreOrders o
        INNER JOIN StoreEscrows e ON o.OrderId = e.OrderId
      `,
    },
  ];

  for (const validation of validations) {
    try {
      const result = await pool.request().query(validation.query);
      const value = result.recordset[0].cnt || result.recordset[0].total || 0;
      console.log(`   ✅ ${validation.name}: ${value}`);
    } catch (error) {
      console.error(`   ❌ Validation failed for ${validation.name}:`, error.message);
    }
  }
}

// ==================== ROLLBACK ====================

async function rollbackMigration(pool) {
  console.log('\n⚠️  ROLLBACK MODE - Deleting migrated records...');
  console.log('   WARNING: This will delete all records from store tables!');
  console.log('   Press Ctrl+C within 10 seconds to cancel...');

  await new Promise(resolve => setTimeout(resolve, 10000));

  const tables = ['StoreEscrows', 'StoreOrders', 'StoreProducts', 'StoreWallets'];

  for (const table of tables) {
    try {
      const result = await pool.request().query(`DELETE FROM ${table}`);
      console.log(`   ✅ Deleted all records from ${table} (${result.rowsAffected[0]} rows)`);
    } catch (error) {
      console.error(`   ❌ Error deleting from ${table}:`, error.message);
    }
  }

  console.log('\n🔄 Rollback complete');
}

// ==================== MAIN ====================

async function main() {
  console.log('╔════════════════════════════════════════════════════════╗');
  console.log('║  CringeStore Firestore → SQL Migration                ║');
  console.log('╚════════════════════════════════════════════════════════╝');
  console.log();
  console.log(`Mode: ${DRY_RUN ? '🔍 DRY RUN' : '✍️  LIVE MIGRATION'}`);
  console.log(`Batch Size: ${EFFECTIVE_BATCH_SIZE}`);
  console.log(`Target Collection: ${TARGET_COLLECTION || 'ALL'}`);
  console.log(`Skip Validation: ${SKIP_VALIDATION}`);
  console.log();

  const pool = await connectSQL();

  try {
    if (ROLLBACK_MODE) {
      await rollbackMigration(pool);
      return;
    }

    const results = {};

    if (!TARGET_COLLECTION || TARGET_COLLECTION === 'products') {
      results.products = await migrateProducts(pool, DRY_RUN);
    }

    if (!TARGET_COLLECTION || TARGET_COLLECTION === 'orders') {
      results.orders = await migrateOrders(pool, DRY_RUN);
    }

    if (!TARGET_COLLECTION || TARGET_COLLECTION === 'escrows') {
      results.escrows = await migrateEscrows(pool, DRY_RUN);
    }

    if (!TARGET_COLLECTION || TARGET_COLLECTION === 'wallets') {
      results.wallets = await migrateWallets(pool, DRY_RUN);
    }

    if (!DRY_RUN && !SKIP_VALIDATION) {
      await validateMigration(pool);
    }

    console.log('\n╔════════════════════════════════════════════════════════╗');
    console.log('║  Migration Summary                                     ║');
    console.log('╚════════════════════════════════════════════════════════╝');
    console.log();

    Object.entries(results).forEach(([collection, result]) => {
      console.log(`${collection.toUpperCase()}:`);
      console.log(`  Total: ${result.total}`);
      console.log(`  Migrated: ${result.migrated}`);
      console.log(`  Errors: ${result.errors}`);
      console.log();
    });

    const totalMigrated = Object.values(results).reduce((sum, r) => sum + r.migrated, 0);
    const totalErrors = Object.values(results).reduce((sum, r) => sum + r.errors, 0);

    console.log(`✅ Migration ${DRY_RUN ? 'simulation' : 'complete'}: ${totalMigrated} records migrated, ${totalErrors} errors`);

    if (DRY_RUN) {
      console.log('\n💡 Run without --dry-run to execute migration');
    }
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await disconnectSQL();
    process.exit(0);
  }
}

// ==================== EXECUTE ====================

main().catch(error => {
  console.error('❌ Unhandled error:', error);
  process.exit(1);
});
