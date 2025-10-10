'use strict';

const sql = require('mssql');

async function ensureFollowEdgeTable(pool) {
  const tableExists = await pool
    .request()
    .query(`SELECT 1
            FROM sys.tables t
            INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
            WHERE s.name = 'dbo' AND t.name = 'FollowEdge';`)
    .then((res) => res.recordset.length > 0);

  if (tableExists) {
    console.log('FollowEdge table already exists.');
    return;
  }

  console.log('Creating dbo.FollowEdge table...');

  await pool.request().query(`
    CREATE TABLE dbo.FollowEdge (
      FollowEdgeId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
      FollowerUserId NVARCHAR(128) NOT NULL,
      TargetUserId NVARCHAR(128) NOT NULL,
      State NVARCHAR(32) NOT NULL,
      Source NVARCHAR(128) NULL,
      CreatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_FollowEdge_CreatedAt DEFAULT SYSUTCDATETIME(),
      UpdatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_FollowEdge_UpdatedAt DEFAULT SYSUTCDATETIME()
    );

    CREATE UNIQUE INDEX IX_FollowEdge_Follower_Target
      ON dbo.FollowEdge (FollowerUserId, TargetUserId);

    CREATE INDEX IX_FollowEdge_Target_Follower
      ON dbo.FollowEdge (TargetUserId, FollowerUserId);
  `);

  console.log('dbo.FollowEdge table created successfully.');
}

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
    await ensureFollowEdgeTable(pool);
  } finally {
    await pool.close();
  }
}

main().catch((err) => {
  console.error('Failed to setup FollowEdge table:', err);
  process.exitCode = 1;
});
