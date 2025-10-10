/**
 * Scheduled Function: Daily Wallet Consistency Check
 * 
 * Her gün saat 02:00 UTC'de çalışır.
 * Firestore ve SQL wallet balances'ları karşılaştırır.
 * Tutarsızlık bulunursa Slack/email alert gönderir.
 */

const functions = require('../regional_functions');
const admin = require('firebase-admin');
const sql = require('mssql');
const { sendSlackAlert, logStructured } = require('../utils/alerts');

// Initialize Firebase (if not already done)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// SQL config
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
 * Compare Firestore and SQL wallet balances
 */
async function validateWalletConsistency() {
  logStructured('INFO', 'Starting wallet consistency check');

  let pool;
  const inconsistencies = [];

  try {
    // Fetch Firestore wallets
    const firestoreWallets = {};
    const walletsSnapshot = await db.collection('wallets').get();
    walletsSnapshot.forEach(doc => {
      const data = doc.data();
      firestoreWallets[doc.id] = data.goldBalance || 0;
    });

    logStructured('INFO', 'Firestore wallets loaded', {
      count: Object.keys(firestoreWallets).length,
    });

    // Fetch SQL wallets
    pool = await sql.connect(sqlConfig);
    const result = await pool.request().query(`
      SELECT AuthUid, GoldBalance
      FROM StoreWallets
    `);

    const sqlWallets = {};
    result.recordset.forEach(row => {
      sqlWallets[row.AuthUid] = row.GoldBalance;
    });

    logStructured('INFO', 'SQL wallets loaded', {
      count: result.recordset.length,
    });

    // Compare balances
    const allAuthUids = new Set([
      ...Object.keys(firestoreWallets),
      ...Object.keys(sqlWallets),
    ]);

    allAuthUids.forEach(authUid => {
      const fsBalance = firestoreWallets[authUid] || 0;
      const sqlBalance = sqlWallets[authUid] || 0;

      if (fsBalance !== sqlBalance) {
        inconsistencies.push({
          authUid,
          firestoreBalance: fsBalance,
          sqlBalance,
          difference: Math.abs(fsBalance - sqlBalance),
        });
      }
    });

    // Report results
    if (inconsistencies.length > 0) {
      logStructured('WARNING', 'Wallet inconsistencies detected', {
        inconsistencyCount: inconsistencies.length,
        sample: inconsistencies.slice(0, 5),
      });

      await sendSlackAlert(
        'CRITICAL',
        'Wallet Consistency Check Failed',
        `Found ${inconsistencies.length} wallet inconsistencies`,
        {
          'Total Checked': allAuthUids.size,
          'Inconsistencies': inconsistencies.length,
          'Largest Difference': Math.max(...inconsistencies.map(i => i.difference)),
        }
      );

      return { success: false, inconsistencies };
    } else {
      logStructured('INFO', 'All wallets consistent', {
        totalChecked: allAuthUids.size,
      });

      return { success: true, totalChecked: allAuthUids.size };
    }
  } catch (error) {
    logStructured('ERROR', 'Wallet consistency check failed', {
      error: error.message,
      stack: error.stack,
    });

    await sendSlackAlert(
      'CRITICAL',
      'Wallet Consistency Check Error',
      `Check failed: ${error.message}`,
      {}
    );

    throw error;
  } finally {
    if (pool) {
      await pool.close();
    }
  }
}

/**
 * Cloud Scheduler triggered function
 * Schedule: 0 2 * * * (Every day at 02:00 UTC)
 */
exports.dailyWalletConsistencyCheck = functions
  .region('europe-west1')
  .pubsub.schedule('0 2 * * *')
  .timeZone('Europe/Istanbul')
  .onRun(async context => {
    try {
      const result = await validateWalletConsistency();
      console.log('Wallet consistency check result:', result);
      return result;
    } catch (error) {
      console.error('Wallet consistency check failed:', error);
      throw error;
    }
  });

// Export for testing
module.exports = { validateWalletConsistency };
