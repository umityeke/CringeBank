const requiredKeys = [
  'SQLSERVER_HOST',
  'SQLSERVER_USER',
  'SQLSERVER_PASS',
  'SQLSERVER_DB',
];

function readSqlConfig() {
  const config = {
    server: process.env.SQLSERVER_HOST,
    user: process.env.SQLSERVER_USER,
    password: process.env.SQLSERVER_PASS,
    database: process.env.SQLSERVER_DB,
    port: process.env.SQLSERVER_PORT ? Number(process.env.SQLSERVER_PORT) : undefined,
    pool: {
      max: Number.parseInt(process.env.SQLSERVER_POOL_MAX || '10', 10),
      min: Number.parseInt(process.env.SQLSERVER_POOL_MIN || '0', 10),
      idleTimeoutMillis: Number.parseInt(process.env.SQLSERVER_POOL_IDLE || '30000', 10),
    },
    options: {
      encrypt: process.env.SQLSERVER_ENCRYPT === 'false' ? false : true,
      trustServerCertificate: process.env.SQLSERVER_TRUST_CERT === 'true',
    },
  };

  const missing = requiredKeys.filter((key) => !process.env[key]);
  if (missing.length > 0) {
    throw new Error(`Missing SQL Server configuration keys: ${missing.join(', ')}`);
  }

  return config;
}

module.exports = {
  readSqlConfig,
};
