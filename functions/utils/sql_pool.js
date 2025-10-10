const sql = require('mssql');

let cachedPool = null;

const buildConfig = () => {
  const {
    SQL_SERVER,
    SQL_DATABASE,
    SQL_USER,
    SQL_PASSWORD,
    SQL_ENCRYPT,
    SQL_TRUST_SERVER_CERTIFICATE,
    SQL_POOL_MAX,
    SQL_POOL_MIN,
    SQL_POOL_IDLE,
  } = process.env;

  if (!SQL_SERVER || !SQL_DATABASE || !SQL_USER || !SQL_PASSWORD) {
    throw new Error('SQL bağlantı ayarları eksik. SQL_SERVER, SQL_DATABASE, SQL_USER ve SQL_PASSWORD gereklidir.');
  }

  return {
    server: SQL_SERVER,
    database: SQL_DATABASE,
    user: SQL_USER,
    password: SQL_PASSWORD,
    options: {
      encrypt: SQL_ENCRYPT ? SQL_ENCRYPT === 'true' : true,
      trustServerCertificate: SQL_TRUST_SERVER_CERTIFICATE === 'true',
    },
    pool: {
      max: SQL_POOL_MAX ? Number(SQL_POOL_MAX) : 10,
      min: SQL_POOL_MIN ? Number(SQL_POOL_MIN) : 2,
      idleTimeoutMillis: SQL_POOL_IDLE ? Number(SQL_POOL_IDLE) : 30000,
    },
  };
};

const createPool = async () => {
  const config = buildConfig();
  const pool = new sql.ConnectionPool(config);
  pool.on('error', (err) => {
    // eslint-disable-next-line no-console
    console.error('SQL pool hata aldı', err);
    if (cachedPool) {
      cachedPool.close().catch(() => {});
      cachedPool = null;
    }
  });
  await pool.connect();
  return pool;
};

const getSqlPool = async () => {
  if (cachedPool && cachedPool.connected) {
    return cachedPool;
  }

  cachedPool = await createPool();
  return cachedPool;
};

const resetSqlPool = async () => {
  if (cachedPool) {
    try {
      await cachedPool.close();
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('SQL pool kapatılamadı', error);
    }
    cachedPool = null;
  }
};

module.exports = {
  getSqlPool,
  resetSqlPool,
};
