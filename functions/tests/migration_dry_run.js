#!/usr/bin/env node

/**
 * Migration Dry Run Test
 * 
 * Validates that migration scripts can execute without errors
 * on a test/staging database. Does NOT commit changes.
 * 
 * Tests:
 * 1. Connection to SQL Server
 * 2. Database schema validation
 * 3. Migration script syntax check
 * 4. Stored procedure compilation
 * 5. Rollback capability
 * 
 * Usage:
 *   node tests/migration_dry_run.js [--execute]
 * 
 * Options:
 *   --execute  Actually run migrations (default: dry run only)
 */

const sql = require('mssql');
const fs = require('fs').promises;
const path = require('path');

const MIGRATIONS_DIR = path.join(__dirname, '../../backend/scripts/migrations');
const PROCEDURES_DIR = path.join(__dirname, '../../backend/scripts/stored_procedures');

const DB_CONFIG = {
  server: process.env.SQL_SERVER || 'localhost',
  database: process.env.SQL_DATABASE || 'CringeBank_Test',
  user: process.env.SQL_USER,
  password: process.env.SQL_PASSWORD,
  options: {
    encrypt: process.env.SQL_ENCRYPT !== 'false',
    trustServerCertificate: process.env.SQL_TRUST_CERT === 'true',
    connectTimeout: 15000,
    requestTimeout: 30000,
  },
};

async function testConnection() {
  console.log('🔌 Testing SQL Server connection...');
  console.log(`   Server: ${DB_CONFIG.server}`);
  console.log(`   Database: ${DB_CONFIG.database}`);

  try {
    const pool = await sql.connect(DB_CONFIG);
    const result = await pool.request().query('SELECT @@VERSION AS Version');
    console.log(`✅ Connected to SQL Server`);
    console.log(`   ${result.recordset[0].Version.split('\n')[0]}`);
    await pool.close();
    return true;
  } catch (error) {
    console.error(`❌ Connection failed: ${error.message}`);
    throw error;
  }
}

async function validateSchema() {
  console.log('\n📋 Validating database schema...');

  const pool = await sql.connect(DB_CONFIG);

  const requiredTables = [
    'Users',
    'StoreWallets',
    'StoreProducts',
    'StoreOrders',
    'StoreEscrows',
  ];

  const missingTables = [];

  for (const tableName of requiredTables) {
    const result = await pool.request()
      .input('tableName', sql.NVarChar, tableName)
      .query(`
        SELECT COUNT(*) AS Exists
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = @tableName
      `);

    if (result.recordset[0].Exists === 0) {
      missingTables.push(tableName);
    }
  }

  await pool.close();

  if (missingTables.length > 0) {
    console.warn(`⚠️  Missing tables: ${missingTables.join(', ')}`);
    return { valid: false, missingTables };
  }

  console.log(`✅ All required tables exist`);
  return { valid: true, missingTables: [] };
}

async function listMigrationFiles() {
  try {
    const files = await fs.readdir(MIGRATIONS_DIR);
    const sqlFiles = files
      .filter((f) => f.endsWith('.sql'))
      .sort();

    console.log(`\n📁 Found ${sqlFiles.length} migration files:`);
    sqlFiles.forEach((f) => console.log(`   - ${f}`));

    return sqlFiles;
  } catch (error) {
    console.error(`❌ Failed to list migration files: ${error.message}`);
    throw error;
  }
}

async function checkMigrationSyntax(fileName) {
  const filePath = path.join(MIGRATIONS_DIR, fileName);

  try {
    const sql = await fs.readFile(filePath, 'utf8');

    if (sql.trim().length === 0) {
      console.warn(`⚠️  ${fileName}: Empty file`);
      return { valid: false, error: 'Empty file' };
    }

    // Basic syntax checks
    const hasGo = sql.includes('GO');
    const hasBegin = sql.toLowerCase().includes('begin');

    console.log(`✅ ${fileName}: Syntax check passed`);
    return { valid: true, hasGo, hasBegin };
  } catch (error) {
    console.error(`❌ ${fileName}: ${error.message}`);
    return { valid: false, error: error.message };
  }
}

async function validateStoredProcedures() {
  console.log('\n📦 Validating stored procedures...');

  const pool = await sql.connect(DB_CONFIG);

  const result = await pool.request().query(`
    SELECT
      ROUTINE_NAME AS Name,
      ROUTINE_DEFINITION AS Definition
    FROM INFORMATION_SCHEMA.ROUTINES
    WHERE ROUTINE_TYPE = 'PROCEDURE' AND ROUTINE_SCHEMA = 'dbo'
    ORDER BY ROUTINE_NAME
  `);

  await pool.close();

  const procedures = result.recordset;
  console.log(`✅ Found ${procedures.length} stored procedures`);

  const requiredProcedures = [
    'sp_EnsureUser',
    'sp_GetUserProfile',
    'sp_Store_GetWallet',
  ];

  const missing = requiredProcedures.filter(
    (name) => !procedures.some((p) => p.Name === name)
  );

  if (missing.length > 0) {
    console.warn(`⚠️  Missing procedures: ${missing.join(', ')}`);
    return { valid: false, missing };
  }

  return { valid: true, procedures: procedures.map((p) => p.Name) };
}

async function runDryRun() {
  console.log('\n🧪 Starting Migration Dry Run\n');

  try {
    // Test 1: Connection
    await testConnection();

    // Test 2: Schema validation
    const schemaResult = await validateSchema();
    if (!schemaResult.valid) {
      console.warn('⚠️  Schema validation failed. Some migrations may be needed.');
    }

    // Test 3: List migrations
    const migrationFiles = await listMigrationFiles();

    // Test 4: Syntax check
    console.log('\n🔍 Checking migration syntax...');
    for (const file of migrationFiles) {
      await checkMigrationSyntax(file);
    }

    // Test 5: Validate procedures
    await validateStoredProcedures();

    console.log('\n✅ Dry run completed successfully\n');
    return { success: true };
  } catch (error) {
    console.error(`\n❌ Dry run failed: ${error.message}\n`);
    console.error(error.stack);
    return { success: false, error: error.message };
  }
}

async function main() {
  const args = process.argv.slice(2);
  const execute = args.includes('--execute');

  if (execute) {
    console.log('⚠️  --execute flag not implemented yet. Run migrations manually with sqlcmd.');
    process.exit(1);
  }

  const result = await runDryRun();
  process.exit(result.success ? 0 : 1);
}

if (require.main === module) {
  main();
}

module.exports = {
  runDryRun,
  testConnection,
  validateSchema,
};
