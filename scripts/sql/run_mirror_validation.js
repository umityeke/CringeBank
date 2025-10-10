'use strict';

const { main: runConsistency, defaultOptions } = require('../dm_follow_consistency');

function parseChecks(raw) {
  if (!raw) {
    return ['conversations', 'messages', 'follow'];
  }
  return raw
    .split(',')
    .map((token) => token.trim().toLowerCase())
    .filter(Boolean);
}

function parseLimit(raw) {
  const parsed = Number.parseInt(raw || '', 10);
  if (Number.isNaN(parsed) || parsed <= 0) {
    return defaultOptions.limit;
  }
  return Math.min(parsed, 500);
}

async function main() {
  const checks = parseChecks(process.env.SQL_MIRROR_VALIDATION_CHECKS);
  const limit = parseLimit(process.env.SQL_MIRROR_VALIDATION_LIMIT);
  const verbose = process.env.SQL_MIRROR_VALIDATION_VERBOSE === 'true';
  const threshold = Number.parseInt(
    process.env.SQL_MIRROR_LATENCY_THRESHOLD_MS || '200',
    10,
  );

  const summary = await runConsistency({
    checks,
    limit,
    output: 'json',
    verbose,
    setExitCode: true,
    silent: false,
  });

  const payload = {
    timestamp: new Date().toISOString(),
    thresholdMs: Number.isFinite(threshold) ? threshold : 200,
    limit,
    verbose,
    checks,
    summary,
  };

  console.log(JSON.stringify(payload, null, 2));
}

if (require.main === module) {
  main().catch((error) => {
    console.error('[sql-mirror-validation] failed', {
      error: error.message,
      stack: error.stack,
      cwd: process.cwd(),
    });
    if (!process.exitCode) {
      process.exitCode = 1;
    }
  });
}

module.exports = { main };
