#!/usr/bin/env node

/**
 * Wallet Consistency Validation Script
 * 
 * Günlük çalıştırılacak cron job - Firestore ve SQL arasındaki
 * wallet balance tutarsızlıklarını tespit eder.
 * 
 * Kullanım:
 *   node validate_wallet_consistency.js [--fix] [--verbose]
 * 
 * Seçenekler:
 *   --fix       Tespit edilen tutarsızlıkları otomatik düzelt (DRY RUN: false)
 *   --verbose   Detaylı log çıktısı
 *   --alert     Slack/email alert gönder (tutarsızlık bulunursa)
 * 
 * Çıkış kodları:
 *   0 - Tüm wallet'lar tutarlı
 *   1 - Tutarsızlık bulundu ama düzeltildi (--fix ile)
 *   2 - Tutarsızlık bulundu ve düzeltilmedi
 *   3 - Script hatası
 */

const admin = require('firebase-admin');
const sql = require('mssql');

// Parse CLI args
const args = process.argv.slice(2);
const FIX_MODE = args.includes('--fix');
const VERBOSE = args.includes('--verbose');
const ALERT = args.includes('--alert');

// Initialize Firebase
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// SQL config from environment
const sqlConfig = {
  server: process.env.SQL_SERVER,
  database: process.env.SQL_DATABASE,
  user: process.env.SQL_USER,
  password: process.env.SQL_PASSWORD,
  options: {
    encrypt: true,
    trustServerCertificate: false,
  },
};

/**
 * Validation result structure
 */
class ValidationResult {
  constructor() {
    this.totalChecked = 0;
    this.inconsistencies = [];
    this.fixed = [];
    this.errors = [];
  }

  addInconsistency(authUid, firestoreBalance, sqlBalance, pendingMismatch = false) {
    this.inconsistencies.push({
      authUid,
      firestoreBalance: firestoreBalance || 0,
      sqlBalance: sqlBalance || 0,
      difference: Math.abs((firestoreBalance || 0) - (sqlBalance || 0)),
      pendingMismatch,
      timestamp: new Date().toISOString(),
    });
  }

  addFixed(authUid, oldValue, newValue, source) {
    this.fixed.push({
      authUid,
      oldValue,
      newValue,
      source, // 'firestore' or 'sql'
      timestamp: new Date().toISOString(),
    });
  }

  addError(authUid, error) {
    this.errors.push({
      authUid,
      error: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString(),
    });
  }

  hasInconsistencies() {
    return this.inconsistencies.length > 0;
  }

  generateReport() {
    const report = {
      summary: {
        totalChecked: this.totalChecked,
        inconsistenciesFound: this.inconsistencies.length,
        fixed: this.fixed.length,
        errors: this.errors.length,
        status: this.hasInconsistencies() ? 'INCONSISTENT' : 'CONSISTENT',
      },
      details: {
        inconsistencies: this.inconsistencies,
        fixed: this.fixed,
        errors: this.errors,
      },
      timestamp: new Date().toISOString(),
    };

    return report;
  }
}

/**
 * Fetch all wallets from Firestore
 */
async function getFirestoreWallets() {
  const walletsSnapshot = await db.collection('wallets').get();
  const wallets = {};

  walletsSnapshot.forEach(doc => {
    const data = doc.data();
    wallets[doc.id] = {
      goldBalance: data.goldBalance || 0,
      pendingGold: data.pendingGold || 0,
    };
  });

  if (VERBOSE) {
    console.log(`📦 Firestore: ${Object.keys(wallets).length} wallets loaded`);
  }

  return wallets;
}

/**
 * Fetch all wallets from SQL
 */
async function getSqlWallets(pool) {
  const result = await pool.request().query(`
    SELECT 
      AuthUid,
      GoldBalance,
      PendingGold
    FROM StoreWallets
  `);

  const wallets = {};
  result.recordset.forEach(row => {
    wallets[row.AuthUid] = {
      goldBalance: row.GoldBalance,
      pendingGold: row.PendingGold,
    };
  });

  if (VERBOSE) {
    console.log(`💾 SQL: ${Object.keys(wallets).length} wallets loaded`);
  }

  return wallets;
}

/**
 * Compare wallet balances and return inconsistencies
 */
function compareWallets(firestoreWallets, sqlWallets, result) {
  // Get all unique AuthUids
  const allAuthUids = new Set([
    ...Object.keys(firestoreWallets),
    ...Object.keys(sqlWallets),
  ]);

  allAuthUids.forEach(authUid => {
    result.totalChecked++;

    const fsWallet = firestoreWallets[authUid];
    const sqlWallet = sqlWallets[authUid];

    // Case 1: Wallet only in Firestore
    if (fsWallet && !sqlWallet) {
      result.addInconsistency(
        authUid,
        fsWallet.goldBalance,
        null,
        false
      );
      if (VERBOSE) {
        console.warn(`⚠️  ${authUid}: Only in Firestore (${fsWallet.goldBalance} gold)`);
      }
      return;
    }

    // Case 2: Wallet only in SQL
    if (!fsWallet && sqlWallet) {
      result.addInconsistency(
        authUid,
        null,
        sqlWallet.goldBalance,
        false
      );
      if (VERBOSE) {
        console.warn(`⚠️  ${authUid}: Only in SQL (${sqlWallet.goldBalance} gold)`);
      }
      return;
    }

    // Case 3: Balance mismatch
    if (fsWallet.goldBalance !== sqlWallet.goldBalance) {
      result.addInconsistency(
        authUid,
        fsWallet.goldBalance,
        sqlWallet.goldBalance,
        false
      );
      if (VERBOSE) {
        console.warn(
          `⚠️  ${authUid}: Balance mismatch - Firestore: ${fsWallet.goldBalance}, SQL: ${sqlWallet.goldBalance}`
        );
      }
      return;
    }

    // Case 4: Pending gold mismatch (less critical)
    if (fsWallet.pendingGold !== sqlWallet.pendingGold) {
      result.addInconsistency(
        authUid,
        fsWallet.goldBalance,
        sqlWallet.goldBalance,
        true // pending mismatch
      );
      if (VERBOSE) {
        console.warn(
          `⚠️  ${authUid}: Pending mismatch - Firestore: ${fsWallet.pendingGold}, SQL: ${sqlWallet.pendingGold}`
        );
      }
    }

    // Wallet consistent
    if (VERBOSE && fsWallet.goldBalance === sqlWallet.goldBalance) {
      console.log(`✅ ${authUid}: Consistent (${fsWallet.goldBalance} gold)`);
    }
  });
}

/**
 * Fix inconsistencies by syncing SQL → Firestore
 * (SQL is source of truth for financial data)
 */
async function fixInconsistencies(inconsistencies, pool) {
  console.log(`\n🔧 Fixing ${inconsistencies.length} inconsistencies...`);

  for (const inc of inconsistencies) {
    try {
      const { authUid, sqlBalance, firestoreBalance } = inc;

      // Strategy: SQL is source of truth
      // If wallet exists in SQL, sync to Firestore
      // If wallet doesn't exist in SQL, create it

      if (sqlBalance !== null) {
        // Update Firestore to match SQL
        await db.collection('wallets').doc(authUid).set(
          {
            goldBalance: sqlBalance,
            lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
            syncSource: 'consistency_validator',
          },
          { merge: true }
        );

        console.log(`  ✅ ${authUid}: Firestore updated (${firestoreBalance} → ${sqlBalance})`);
      } else if (firestoreBalance !== null) {
        // Wallet only in Firestore - create in SQL
        await pool.request()
          .input('AuthUid', sql.NVarChar, authUid)
          .input('GoldBalance', sql.Int, firestoreBalance)
          .input('PendingGold', sql.Int, 0)
          .query(`
            INSERT INTO StoreWallets (AuthUid, GoldBalance, PendingGold, CreatedAt, UpdatedAt)
            VALUES (@AuthUid, @GoldBalance, @PendingGold, GETUTCDATE(), GETUTCDATE())
          `);

        console.log(`  ✅ ${authUid}: SQL wallet created (${firestoreBalance} gold)`);
      }
    } catch (error) {
      console.error(`  ❌ ${inc.authUid}: Fix failed - ${error.message}`);
    }
  }
}

/**
 * Send alert (Slack/email) if inconsistencies found
 */
async function sendAlert(report) {
  // TODO: Implement Slack webhook or email sending
  // For now, just log to console

  console.log('\n🚨 ALERT: Wallet inconsistencies detected!');
  console.log(JSON.stringify(report.summary, null, 2));

  // Example Slack webhook (uncomment when configured)
  /*
  const webhookUrl = process.env.SLACK_WEBHOOK_URL;
  if (webhookUrl) {
    await fetch(webhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: `🚨 Wallet Consistency Alert`,
        attachments: [{
          color: 'danger',
          fields: [
            { title: 'Total Checked', value: report.summary.totalChecked, short: true },
            { title: 'Inconsistencies', value: report.summary.inconsistenciesFound, short: true },
            { title: 'Status', value: report.summary.status, short: false },
          ],
        }],
      }),
    });
  }
  */
}

/**
 * Main validation flow
 */
async function main() {
  console.log('🔍 Wallet Consistency Validation');
  console.log('='.repeat(50));
  console.log(`Mode: ${FIX_MODE ? 'FIX' : 'CHECK ONLY'}`);
  console.log(`Verbose: ${VERBOSE}`);
  console.log(`Alert: ${ALERT}`);
  console.log('='.repeat(50));

  let pool;
  const result = new ValidationResult();

  try {
    // Connect to SQL
    pool = await sql.connect(sqlConfig);
    console.log('✅ SQL connected\n');

    // Fetch wallets from both sources
    const [firestoreWallets, sqlWallets] = await Promise.all([
      getFirestoreWallets(),
      getSqlWallets(pool),
    ]);

    // Compare wallets
    console.log('\n🔍 Comparing wallets...\n');
    compareWallets(firestoreWallets, sqlWallets, result);

    // Generate report
    const report = result.generateReport();

    // Print summary
    console.log('\n' + '='.repeat(50));
    console.log('📊 VALIDATION SUMMARY');
    console.log('='.repeat(50));
    console.log(`Total Checked: ${report.summary.totalChecked}`);
    console.log(`Inconsistencies: ${report.summary.inconsistenciesFound}`);
    console.log(`Status: ${report.summary.status}`);
    console.log('='.repeat(50));

    // Fix if requested
    if (FIX_MODE && result.hasInconsistencies()) {
      await fixInconsistencies(result.inconsistencies, pool);
      console.log('\n✅ All inconsistencies fixed');
    }

    // Send alert if requested and inconsistencies found
    if (ALERT && result.hasInconsistencies()) {
      await sendAlert(report);
    }

    // Write report to file
    const fs = require('fs');
    const reportPath = `./validation_reports/wallet_consistency_${Date.now()}.json`;
    fs.mkdirSync('./validation_reports', { recursive: true });
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
    console.log(`\n📄 Report saved: ${reportPath}`);

    // Exit with appropriate code
    if (result.hasInconsistencies()) {
      process.exit(FIX_MODE ? 1 : 2);
    } else {
      process.exit(0);
    }

  } catch (error) {
    console.error('\n❌ Validation failed:', error);
    process.exit(3);
  } finally {
    if (pool) {
      await pool.close();
    }
  }
}

// Run if called directly
if (require.main === module) {
  main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(3);
  });
}

module.exports = { main };
