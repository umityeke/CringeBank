#!/usr/bin/env node

/**
 * staging_phase0_check.js
 * -----------------------
 * Standardizes Phase 0 verification by chaining the SQL migration dry-run,
 * optional backfill dry-run, and auth⇄SQL consistency check.
 *
 * Usage examples:
 *   node scripts/sql/staging_phase0_check.js
 *   node scripts/sql/staging_phase0_check.js --with-backfill-dry-run
 *   node scripts/sql/staging_phase0_check.js --skip-verify
 *   node scripts/sql/staging_phase0_check.js --migrate-arg=--only=20251007_02 --verify-arg=--limit=1000
 */

const { spawn } = require('child_process');
const path = require('path');

const argv = process.argv.slice(2);

const MIGRATE_ARG_PREFIX = '--migrate-arg=';
const VERIFY_ARG_PREFIX = '--verify-arg=';
const BACKFILL_ARG_PREFIX = '--backfill-arg=';

let skipVerify = false;
let withBackfill = false;

const migrateArgs = ['--dry-run'];
const verifyArgs = ['--skip-migration', '--output=json'];
const backfillArgs = ['--dry-run'];

argv.forEach((arg) => {
  if (arg === '--skip-verify') {
    skipVerify = true;
    return;
  }
  if (arg === '--with-backfill-dry-run') {
    withBackfill = true;
    return;
  }
  if (arg.startsWith(MIGRATE_ARG_PREFIX)) {
    migrateArgs.push(arg.slice(MIGRATE_ARG_PREFIX.length));
    return;
  }
  if (arg.startsWith(VERIFY_ARG_PREFIX)) {
    verifyArgs.push(arg.slice(VERIFY_ARG_PREFIX.length));
    return;
  }
  if (arg.startsWith(BACKFILL_ARG_PREFIX)) {
    backfillArgs.push(arg.slice(BACKFILL_ARG_PREFIX.length));
    return;
  }
  console.warn(`[phase0] Bilinmeyen argüman atlandı: ${arg}`);
});

const repoRoot = path.resolve(__dirname, '..', '..');
const scriptsRoot = path.resolve(__dirname, '..');
const nodeBinary = process.execPath;

const steps = [
  {
    name: 'SQL migration dry-run',
    command: nodeBinary,
    args: [path.resolve(__dirname, 'run_migrations.js'), ...migrateArgs],
  },
];

if (withBackfill) {
  steps.push({
    name: 'Auth→SQL backfill dry-run',
    command: nodeBinary,
    args: [path.resolve(__dirname, 'backfill_auth_users.js'), ...backfillArgs],
  });
}

if (!skipVerify) {
  steps.push({
    name: 'Auth/SQL consistency check',
    command: nodeBinary,
    args: [path.resolve(__dirname, 'verify_auth_sync.js'), ...verifyArgs],
  });
}

async function runStep(step) {
  return new Promise((resolve, reject) => {
    console.info(`[phase0] Başlatılıyor → ${step.name}`);
    const child = spawn(step.command, step.args, {
      cwd: scriptsRoot,
      stdio: 'inherit',
      env: process.env,
    });

    child.on('error', (error) => {
      reject(new Error(`${step.name} başlatılamadı: ${error.message}`));
    });

    child.on('exit', (code) => {
      if (code === 0) {
        console.info(`[phase0] Tamamlandı ✓ ${step.name}`);
        resolve();
      } else {
        reject(new Error(`${step.name} başarısız oldu (exit code ${code}).`));
      }
    });
  });
}

(async () => {
  try {
    for (const step of steps) {
      await runStep(step);
    }
    console.info('[phase0] Tüm adımlar başarıyla tamamlandı.');
  } catch (error) {
    console.error('[phase0] Doğrulama başarısız:', error.message);
    process.exitCode = 1;
  }
})();
