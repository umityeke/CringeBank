#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const dotenv = require('dotenv');
const { resolveProcedureForEvent, executeProcedure } = require('../realtime_mirror/processor');
const { readRealtimeMirrorConfig } = require('../realtime_mirror/config');
const { getPool, resetPool } = require('../sql_gateway/pool');

function logInfo(message, payload = {}) {
  console.info(`[seed] ${message}`, payload);
}

function logWarn(message, payload = {}) {
  console.warn(`[seed] ${message}`, payload);
}

function logError(message, payload = {}) {
  console.error(`[seed] ${message}`, payload);
}

function parseArgs(argv) {
  const args = {
    file: null,
    dryRun: false,
    type: null,
    limit: null,
    help: false,
  };

  for (let i = 2; i < argv.length; i += 1) {
    const token = argv[i];
    switch (token) {
      case '--file':
      case '-f':
        args.file = argv[i + 1];
        i += 1;
        break;
      case '--dry-run':
      case '--dryrun':
        args.dryRun = true;
        break;
      case '--type':
      case '-t':
        args.type = argv[i + 1];
        i += 1;
        break;
      case '--limit':
      case '-l':
        args.limit = Number.parseInt(argv[i + 1], 10);
        i += 1;
        break;
      case '--help':
      case '-h':
        args.help = true;
        break;
      default:
        if (!args.file) {
          args.file = token;
        } else {
          logWarn('Unknown arg ignored', { token });
        }
        break;
    }
  }

  return args;
}

function showHelp() {
  console.log(`Realtime Mirror Seeder\n\n` +
    `Usage: node scripts/seed_realtime_mirror.js [options]\n\n` +
    `Options:\n` +
    `  -f, --file   Path to fixture JSON (default: ./scripts/fixtures/realtime_mirror_seed.json)\n` +
    `  -t, --type   Filter by event type prefix (e.g. dm.message)\n` +
    `  -l, --limit  Process only the first N events after filtering\n` +
    `      --dry-run  Print actions without executing stored procedures\n` +
    `  -h, --help   Show this help message\n`);
}

function loadEnvFiles() {
  const rootDir = path.resolve(__dirname, '..');
  const explicit = process.env.SQL_MIRROR_ENV_FILE
    ? path.resolve(rootDir, process.env.SQL_MIRROR_ENV_FILE)
    : null;
  const defaults = [
    path.join(rootDir, '.env'),
    path.join(rootDir, '.env.local'),
  ];

  const loaded = [];

  for (const candidate of defaults) {
    if (fs.existsSync(candidate)) {
      dotenv.config({ path: candidate, override: false });
      loaded.push(candidate);
    }
  }

  if (explicit && fs.existsSync(explicit)) {
    dotenv.config({ path: explicit, override: true });
    loaded.push(explicit);
  }

  if (loaded.length === 0) {
    logWarn('No .env files loaded – relying on ambient environment variables');
  } else {
    logInfo('Loaded environment files', { loaded });
  }
}

function resolveFixturePath(customPath) {
  if (!customPath) {
    return path.join(__dirname, 'fixtures', 'realtime_mirror_seed.json');
  }
  if (path.isAbsolute(customPath)) {
    return customPath;
  }
  return path.resolve(process.cwd(), customPath);
}

function readFixture(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Fixture file not found: ${filePath}`);
  }

  const raw = fs.readFileSync(filePath, 'utf-8');
  try {
    const data = JSON.parse(raw);
    if (!data || !Array.isArray(data.events)) {
      throw new Error('Fixture must contain an "events" array.');
    }
    return data.events;
  } catch (error) {
    throw new Error(`Invalid JSON in fixture ${filePath}: ${error.message}`);
  }
}

function ensureOperation(type, provided) {
  if (provided) {
    return provided;
  }
  if (!type) {
    return null;
  }
  const parts = type.split('.');
  return parts[parts.length - 1] || null;
}

function randomId() {
  if (crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return crypto.randomBytes(8).toString('hex');
}

function buildEvent(payload, index) {
  if (!payload || !payload.type) {
    throw new Error(`Event at index ${index} is missing "type"`);
  }

  const nowIso = new Date().toISOString();
  const operation = ensureOperation(payload.type, payload.operation || payload.data?.operation);
  const eventId = payload.id || `seed:${payload.type}:${payload.messageId || payload.conversationId || randomId()}`;

  const data = {
    ...payload.data,
    operation,
    document: payload.document ?? payload.data?.document ?? null,
    previousDocument: payload.previousDocument ?? payload.data?.previousDocument ?? null,
    conversationId: payload.conversationId ?? payload.data?.conversationId ?? null,
    messageId: payload.messageId ?? payload.data?.messageId ?? null,
    userId: payload.userId ?? payload.data?.userId ?? null,
    targetId: payload.targetId ?? payload.data?.targetId ?? null,
    timestamp: payload.timestamp ?? payload.data?.timestamp ?? nowIso,
    params: payload.params ?? payload.data?.params ?? {},
    source: payload.sourceLabel ?? payload.data?.source ?? null,
  };

  if (payload.metadata && typeof payload.metadata === 'object') {
    Object.assign(data, payload.metadata);
  }

  Object.keys(data).forEach((key) => {
    if (data[key] === undefined) {
      data[key] = null;
    }
  });

  return {
    id: eventId,
    type: payload.type,
    source: payload.source || `seed://${payload.type.replace(/\./g, '/')}`,
    specversion: '1.0',
    time: payload.time || nowIso,
    data,
  };
}

async function seedEvents(events, { dryRun, typeFilter, limit }) {
  loadEnvFiles();
  const config = readRealtimeMirrorConfig();
  const pool = await getPool();

  let processed = 0;
  let skipped = 0;
  let failures = 0;

  try {
    for (let idx = 0; idx < events.length; idx += 1) {
      if (limit !== null && processed >= limit) {
        break;
      }

      const payload = events[idx];
      if (typeFilter && !payload.type.startsWith(typeFilter)) {
        continue;
      }

      let event;
      try {
        event = buildEvent(payload, idx);
      } catch (error) {
        failures += 1;
        logError('Skipping malformed event', { index: idx, error: error.message });
        continue;
      }

      const procedure = resolveProcedureForEvent(event, config.sqlProcedures);
      if (!procedure) {
        skipped += 1;
        logWarn('No stored procedure mapped for event type, skipping', {
          index: idx,
          type: event.type,
        });
        continue;
      }

      if (dryRun) {
        processed += 1;
        logInfo('DRY-RUN would execute procedure', {
          procedure,
          type: event.type,
          metadata: {
            conversationId: event.data.conversationId,
            messageId: event.data.messageId,
            userId: event.data.userId,
            targetId: event.data.targetId,
          },
        });
        continue;
      }

      try {
        await executeProcedure(pool, procedure, event);
        processed += 1;
        logInfo('Executed procedure', {
          procedure,
          type: event.type,
          metadata: {
            conversationId: event.data.conversationId,
            messageId: event.data.messageId,
            userId: event.data.userId,
            targetId: event.data.targetId,
          },
        });
      } catch (error) {
        failures += 1;
        logError('Stored procedure execution failed', {
          index: idx,
          type: event.type,
          procedure,
          error: error.message,
        });
      }
    }
  } finally {
    await resetPool();
  }

  return { processed, skipped, failures };
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help) {
    showHelp();
    return;
  }

  const fixturePath = resolveFixturePath(args.file);
  logInfo('Loading fixture', { fixturePath });

  const events = readFixture(fixturePath);
  if (events.length === 0) {
    logWarn('Fixture contains no events');
    return;
  }

  const { processed, skipped, failures } = await seedEvents(events, {
    dryRun: args.dryRun,
    typeFilter: args.type || null,
    limit: Number.isInteger(args.limit) ? args.limit : null,
  });

  logInfo('Seed completed', { processed, skipped, failures, dryRun: args.dryRun });

  if (failures > 0) {
    process.exitCode = 1;
  }
}

if (require.main === module) {
  main().catch((error) => {
    logError('Fatal error', { error: error.message });
    process.exit(1);
  });
}
