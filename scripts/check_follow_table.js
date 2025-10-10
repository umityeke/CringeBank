'use strict';

const sql = require('mssql');

async function main() {
  const config = {
    server: process.env.SQLSERVER_HOST,
    user: process.env.SQLSERVER_USER,
    password: process.env.SQLSERVER_PASS,
    database: process.env.SQLSERVER_DB,
    options: {
      encrypt: process.env.SQLSERVER_ENCRYPT !== 'false',
      trustServerCertificate: process.env.SQLSERVER_TRUST_CERT === 'true',
    },
  };

  if (!config.server || !config.user || !config.password || !config.database) {
    throw new Error('Missing SQLSERVER_* environment variables');
  }

  const pool = await sql.connect(config);
  try {
    const result = await pool.request().query(`SELECT s.name AS schemaName, t.name AS tableName
      FROM sys.tables t
      INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
      WHERE t.name = 'FollowEdge';`);

    if (result.recordset.length === 0) {
      console.log('FollowEdge table not found in database:', config.database);
    } else {
      console.log('FollowEdge table exists in database:', config.database);
      for (const row of result.recordset) {
        console.log(`- ${row.schemaName}.${row.tableName}`);
      }
    }
  } finally {
    await pool.close();
  }
}

main().catch((err) => {
  console.error('Failed to verify FollowEdge table:', err.message);
  process.exitCode = 1;
});
