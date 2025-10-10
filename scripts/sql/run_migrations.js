#!/usr/bin/env node

/**
 * Run SQL migration and stored procedure scripts in order using the mssql driver.
 *
 * Usage examples:
 *   node scripts/sql/run_migrations.js
 *   node scripts/sql/run_migrations.js --dry-run
 *   node scripts/sql/run_migrations.js --only=20251007_01_create_users_table.sql
 *   node scripts/sql/run_migrations.js --skip-procs
 *
 * Environment variables (same as backfill script):
 *   SQLSERVER_HOST, SQLSERVER_USER, SQLSERVER_PASS, SQLSERVER_DB
 *   Optional: SQLSERVER_PORT, SQLSERVER_POOL_MAX, SQLSERVER_POOL_MIN,
 *             SQLSERVER_POOL_IDLE, SQLSERVER_ENCRYPT, SQLSERVER_TRUST_CERT
 */

const fs = require('fs/promises');
const path = require('path');
const mssql = require('mssql');

const argv = process.argv.slice(2);

const hasFlag = (flag) => argv.includes(flag);
const getOption = (name) => {
  const prefix = `--${name}=`;
  const arg = argv.find((item) => item.startsWith(prefix));
  return arg ? arg.slice(prefix.length) : undefined;
};

const isDryRun = hasFlag('--dry-run');
const onlyPattern = getOption('only');
const skipProcedures = hasFlag('--skip-procs');

const sqlConfig = {
  server: process.env.SQLSERVER_HOST,
  user: process.env.SQLSERVER_USER,
  password: process.env.SQLSERVER_PASS,
  database: process.env.SQLSERVER_DB,
  port: process.env.SQLSERVER_PORT ? Number(process.env.SQLSERVER_PORT) : undefined,
  pool: {
    max: Number.parseInt(process.env.SQLSERVER_POOL_MAX || '5', 10),
    min: Number.parseInt(process.env.SQLSERVER_POOL_MIN || '0', 10),
    idleTimeoutMillis: Number.parseInt(process.env.SQLSERVER_POOL_IDLE || '30000', 10),
  },
  options: {
    encrypt: process.env.SQLSERVER_ENCRYPT === 'false' ? false : true,
    trustServerCertificate: process.env.SQLSERVER_TRUST_CERT === 'true',
  },
};

function ensureSqlConfigValid() {
  const missing = [];
  if (!sqlConfig.server) missing.push('SQLSERVER_HOST');
  if (!sqlConfig.user) missing.push('SQLSERVER_USER');
  if (!sqlConfig.password) missing.push('SQLSERVER_PASS');
  if (!sqlConfig.database) missing.push('SQLSERVER_DB');
  if (missing.length > 0) {
    throw new Error(`Missing SQL configuration variables: ${missing.join(', ')}`);
  }
}

let poolPromise;
async function getPool() {
  if (!poolPromise) {
    ensureSqlConfigValid();
    poolPromise = (async () => {
      const pool = new mssql.ConnectionPool(sqlConfig);
      pool.on('error', (error) => {
        console.error('[migrations] SQL pool error', error);
      });
      await pool.connect();
      return pool;
    })();
  }
  return poolPromise;
}

function splitBatches(sqlText) {
  const lines = sqlText.split(/\r?\n/);
  const batches = [];
  let current = [];

  const pushBatch = () => {
    const trimmed = current.join('\n').trim();
    if (trimmed.length > 0) {
      batches.push(trimmed);
    }
    current = [];
  };

  for (const line of lines) {
    if (/^\s*GO\s*$/i.test(line)) {
      pushBatch();
    } else {
      current.push(line);
    }
  }

  pushBatch();
  return batches;
}

async function executeFile({ pool, filePath }) {
  const fileName = path.basename(filePath);
  console.info(`[migrations] Executing ${fileName}`);
  const sqlText = await fs.readFile(filePath, 'utf8');
  const batches = splitBatches(sqlText);

  if (isDryRun) {
    console.info(`[migrations] Dry-run: ${fileName} contains ${batches.length} batch(es)`);
    return;
  }

  for (let i = 0; i < batches.length; i += 1) {
    const batch = batches[i];
    if (!batch) {
      continue;
    }
    console.info(`[migrations] Batch ${i + 1}/${batches.length} for ${fileName}`);
    try {
      await pool.request().batch(batch);
    } catch (error) {
      error.message = `Failed executing ${fileName} (batch ${i + 1}/${batches.length}): ${error.message}`;
      throw error;
    }
  }
}

async function listSqlFiles(dirPath) {
  const entries = await fs.readdir(dirPath, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith('.sql'))
    .map((entry) => entry.name)
    .sort((a, b) => a.localeCompare(b));
}

async function run() {
  console.info('[migrations] Starting', { dryRun: isDryRun, onlyPattern, skipProcedures });

  const migrationsDir = path.resolve(__dirname, '..', '..', 'backend', 'scripts', 'migrations');
  const proceduresDir = path.resolve(__dirname, '..', '..', 'backend', 'scripts', 'stored_procedures');

  const tasks = [];

  const migrationFiles = await listSqlFiles(migrationsDir);
  for (const file of migrationFiles) {
    if (onlyPattern && !file.includes(onlyPattern)) {
      continue;
    }
    tasks.push({ type: 'migration', filePath: path.join(migrationsDir, file) });
  }

  if (!skipProcedures) {
    try {
      const procedureFiles = await listSqlFiles(proceduresDir);
      for (const file of procedureFiles) {
        if (onlyPattern && !file.includes(onlyPattern)) {
          continue;
        }
        tasks.push({ type: 'procedure', filePath: path.join(proceduresDir, file) });
      }
    } catch (error) {
      if (error.code === 'ENOENT') {
        console.info('[migrations] Stored procedures directory not found, skipping.');
      } else {
        throw error;
      }
    }
  }

  if (tasks.length === 0) {
    console.info('[migrations] No matching SQL files to execute.');
    return;
  }

  let pool = null;
  if (!isDryRun) {
    pool = await getPool();
  }

  try {
    for (const task of tasks) {
      await executeFile({ pool, filePath: task.filePath });
    }
  } finally {
    if (pool) {
      await pool.close().catch((error) => {
        console.error('[migrations] Error closing pool', error);
      });
    }
  }

  console.info('[migrations] Completed successfully.');
}

run().catch((error) => {
  console.error('[migrations] Failed', error);
  process.exitCode = 1;
});
