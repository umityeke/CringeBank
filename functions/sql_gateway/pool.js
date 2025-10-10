const mssql = require('mssql');
const functions = require('firebase-functions');
const { readSqlConfig } = require('./config');

let poolPromise = null;

async function createPool() {
  const config = readSqlConfig();
  const pool = new mssql.ConnectionPool(config);

  pool.on('error', (error) => {
    functions.logger.error('sqlGateway.pool_error', error);
    resetPool().catch((resetError) => {
      functions.logger.error('sqlGateway.pool_reset_failed', resetError);
    });
  });

  return pool.connect();
}

async function getPool() {
  if (poolPromise) {
    try {
      const existing = await poolPromise;
      if (existing?.connected) {
        return existing;
      }
    } catch (error) {
      functions.logger.warn('sqlGateway.pool_reuse_failed', error);
    }
    poolPromise = null;
  }

  poolPromise = createPool();
  return poolPromise;
}

async function resetPool() {
  if (!poolPromise) {
    return;
  }

  const current = poolPromise;
  poolPromise = null;

  try {
    const pool = await current;
    if (pool?.close) {
      await pool.close();
    }
  } catch (error) {
    functions.logger.error('sqlGateway.pool_close_failed', error);
  }
}

module.exports = {
  getPool,
  resetPool,
};
