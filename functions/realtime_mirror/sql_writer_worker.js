'use strict';

const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
const functions = require('../regional_functions');
const { createSqlWriterProcessor, readRealtimeMirrorConfig } = require('./index');

function resolvePath(filePath) {
  if (!filePath) {
    return null;
  }
  if (path.isAbsolute(filePath)) {
    return filePath;
  }
  return path.resolve(__dirname, '..', filePath);
}

function loadEnvFiles() {
  const rootDir = path.resolve(__dirname, '..');
  const explicitPath = resolvePath(process.env.SQL_MIRROR_ENV_FILE);
  const candidates = [path.join(rootDir, '.env'), path.join(rootDir, '.env.local')];

  const loaded = [];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      dotenv.config({ path: candidate, override: false });
      loaded.push(candidate);
    }
  }

  if (explicitPath && fs.existsSync(explicitPath)) {
    dotenv.config({ path: explicitPath, override: true });
    loaded.push(explicitPath);
  }

  if (loaded.length === 0) {
    console.warn('[sql-writer] No .env file loaded; relying on existing environment variables.');
  } else {
    console.info('[sql-writer] Loaded environment files:', loaded);
  }
}

async function main() {
  process.env.FUNCTIONS_EMULATOR = process.env.FUNCTIONS_EMULATOR || 'true';
  loadEnvFiles();

  const config = readRealtimeMirrorConfig();
  const processor = createSqlWriterProcessor();
  const subscriptions = [];

  const shutdown = async (signal) => {
    console.info(`[sql-writer] Received ${signal}, shutting down processor...`);
    try {
      await processor.stop();
      console.info('[sql-writer] SQL writer processor stopped.');
    } catch (error) {
      console.error('[sql-writer] Failed to stop processor cleanly:', error);
      process.exitCode = 1;
    } finally {
      subscriptions.forEach(({ signal: sig, handler }) => process.off(sig, handler));
      setTimeout(() => process.exit(), 250);
    }
  };

  const signals = ['SIGINT', 'SIGTERM', 'SIGQUIT'];
  for (const signal of signals) {
    const handler = () => shutdown(signal);
    subscriptions.push({ signal, handler });
    process.on(signal, handler);
  }

  process.on('unhandledRejection', (reason) => {
    functions.logger.error('realtimeMirror.sqlWriter_unhandled_rejection', {
      reason: reason instanceof Error ? reason.message : reason,
    });
  });

  process.on('uncaughtException', (error) => {
    functions.logger.error('realtimeMirror.sqlWriter_uncaught_exception', {
      message: error?.message,
      stack: error?.stack,
    });
    shutdown('uncaughtException');
  });

  const { serviceBus } = config;
  functions.logger.info('realtimeMirror.sqlWriter_launching', {
    topic: serviceBus.topicName,
    subscription: serviceBus.subscriptions.sqlWriter,
  });

  processor.start();
}

if (require.main === module) {
  main().catch((error) => {
    console.error('[sql-writer] Fatal launch error:', error);
    process.exit(1);
  });
}
