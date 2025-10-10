/**
 * Scheduled Function: Hourly SQL Metrics Collection
 * 
 * Her saat başı çalışır.
 * SQL database'den kritik metrikleri toplar.
 * Anomali tespit edilirse alert gönderir.
 */

const functions = require('firebase-functions');
const sql = require('mssql');
const { sendSlackAlert, logStructured } = require('../utils/alerts');

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
 * Collect critical metrics from SQL
 */
async function collectMetrics() {
  logStructured('INFO', 'Starting metrics collection');

  let pool;

  try {
    pool = await sql.connect(sqlConfig);

    const result = await pool.request().query(`
      SELECT 
        (SELECT COUNT(*) FROM StoreWallets WHERE GoldBalance < 0) AS NegativeBalances,
        (SELECT COUNT(*) FROM StoreOrders WHERE OrderStatus = 'PENDING') AS PendingOrders,
        (SELECT COUNT(*) FROM StoreEscrows WHERE EscrowState = 'LOCKED') AS LockedEscrows,
        (SELECT SUM(GoldBalance) FROM StoreWallets) AS TotalGoldBalance,
        (SELECT COUNT(*) FROM StoreOrders WHERE CreatedAt >= DATEADD(hour, -1, GETUTCDATE())) AS OrdersLastHour,
        (SELECT AVG(DATEDIFF(second, CreatedAt, UpdatedAt)) 
         FROM StoreOrders 
         WHERE OrderStatus = 'COMPLETED' 
         AND CreatedAt >= DATEADD(hour, -1, GETUTCDATE())) AS AvgOrderCompletionTimeSec
    `);

    const metrics = result.recordset[0];

    logStructured('INFO', 'Metrics collected', metrics);

    // Alert on negative balances
    if (metrics.NegativeBalances > 0) {
      await sendSlackAlert(
        'CRITICAL',
        'Negative Wallet Balances Detected',
        `Found ${metrics.NegativeBalances} wallet(s) with negative balance!`,
        {
          'Negative Balances': metrics.NegativeBalances,
          'Total Gold in System': metrics.TotalGoldBalance,
          Timestamp: new Date().toISOString(),
        }
      );
    }

    // Alert on stuck orders (too many locked escrows)
    if (metrics.LockedEscrows > 100) {
      await sendSlackAlert(
        'WARNING',
        'High Number of Locked Escrows',
        `${metrics.LockedEscrows} escrows are currently locked`,
        {
          'Locked Escrows': metrics.LockedEscrows,
          'Pending Orders': metrics.PendingOrders,
        }
      );
    }

    // Alert on slow order processing (>5 minutes average)
    if (metrics.AvgOrderCompletionTimeSec > 300) {
      await sendSlackAlert(
        'WARNING',
        'Slow Order Processing',
        `Average order completion time: ${Math.round(metrics.AvgOrderCompletionTimeSec / 60)} minutes`,
        {
          'Avg Completion Time': `${Math.round(metrics.AvgOrderCompletionTimeSec)}s`,
          'Orders Last Hour': metrics.OrdersLastHour,
        }
      );
    }

    return metrics;
  } catch (error) {
    logStructured('ERROR', 'Metrics collection failed', {
      error: error.message,
      stack: error.stack,
    });

    await sendSlackAlert(
      'CRITICAL',
      'Metrics Collection Error',
      `Failed to collect metrics: ${error.message}`,
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
 * Schedule: 0 * * * * (Every hour at minute 0)
 */
exports.hourlyMetricsCollection = functions
  .region('europe-west1')
  .pubsub.schedule('0 * * * *')
  .timeZone('Europe/Istanbul')
  .onRun(async context => {
    try {
      const metrics = await collectMetrics();
      console.log('Hourly metrics:', metrics);
      return metrics;
    } catch (error) {
      console.error('Metrics collection failed:', error);
      throw error;
    }
  });

// Export for testing
module.exports = { collectMetrics };
