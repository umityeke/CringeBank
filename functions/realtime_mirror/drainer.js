'use strict';

const { ServiceBusClient } = require('@azure/service-bus');
const functions = require('firebase-functions');
const { readRealtimeMirrorConfig } = require('./config');
const { resolveProcedureForEvent, executeProcedure } = require('./processor');
const { getPool } = require('../sql_gateway/pool');

const DEFAULT_BATCH_SIZE = 25;
const DEFAULT_MAX_DURATION_MS = 45_000;
const DEFAULT_IDLE_ROUNDS = 2;
const DEFAULT_WAIT_TIME_MS = 2_000;

class RealtimeMirrorDrainer {
  constructor(options = {}) {
    this._config = options.config || readRealtimeMirrorConfig();
    this._batchSize = options.batchSize || DEFAULT_BATCH_SIZE;
    this._maxDurationMs = options.maxDurationMs || DEFAULT_MAX_DURATION_MS;
    this._maxIdleRounds =
      options.maxIdleRounds !== undefined ? options.maxIdleRounds : DEFAULT_IDLE_ROUNDS;
    this._waitTimeMs = options.waitTimeMs || DEFAULT_WAIT_TIME_MS;

    this._client = new ServiceBusClient(this._config.serviceBus.connectionString);
    this._receiver = this._client.createReceiver(
      this._config.serviceBus.topicName,
      this._config.serviceBus.subscriptions.sqlWriter,
      {
        receiveMode: 'peekLock',
        maxAutoLockRenewalDurationInMs: 5 * 60 * 1000,
      },
    );

    this._closed = false;
  }

  async drain() {
    const startedAt = Date.now();
    const deadline = startedAt + this._maxDurationMs;
    let idleRounds = 0;
    let processed = 0;
    let completed = 0;
    let abandoned = 0;
    let skipped = 0;

    const pool = await getPool();

    while (Date.now() < deadline && !this._closed) {
      const remainingMs = Math.max(deadline - Date.now(), 1000);
      const waitTime = Math.min(this._waitTimeMs, remainingMs);
      const messages = await this._receiver.receiveMessages(this._batchSize, {
        maxWaitTimeInMs: waitTime,
      });

      if (!messages.length) {
        idleRounds += 1;
        if (idleRounds > this._maxIdleRounds) {
          break;
        }
        continue;
      }

      idleRounds = 0;

      for (const message of messages) {
        if (this._closed) {
          break;
        }

        processed += 1;
        const event = message.body;

        if (!event || typeof event !== 'object') {
          skipped += 1;
          await this._receiver.completeMessage(message);
          functions.logger.warn('realtimeMirror.drainer_invalid_event', {
            messageId: message.messageId,
          });
          continue;
        }

        const procedureName = resolveProcedureForEvent(event, this._config.sqlProcedures);
        if (!procedureName) {
          skipped += 1;
          await this._receiver.completeMessage(message);
          functions.logger.warn('realtimeMirror.drainer_unknown_event', {
            messageId: message.messageId,
            type: event.type,
          });
          continue;
        }

        try {
          await executeProcedure(pool, procedureName, event);
          await this._receiver.completeMessage(message);
          completed += 1;
        } catch (error) {
          abandoned += 1;
          await this._receiver.abandonMessage(message, {
            reason: 'processing_error',
            error: error?.message,
          });
          functions.logger.error('realtimeMirror.drainer_failure', {
            messageId: message.messageId,
            type: event.type,
            procedure: procedureName,
            error: error?.message,
          });
        }
      }
    }

    return {
      processed,
      completed,
      abandoned,
      skipped,
      durationMs: Date.now() - startedAt,
    };
  }

  async close() {
    if (this._closed) {
      return;
    }
    this._closed = true;
    await Promise.allSettled([
      this._receiver?.close().catch((error) => {
        functions.logger.warn('realtimeMirror.drainer_receiver_close_failed', {
          error: error?.message,
        });
      }),
      this._client?.close().catch((error) => {
        functions.logger.warn('realtimeMirror.drainer_client_close_failed', {
          error: error?.message,
        });
      }),
    ]);
  }
}

function createRealtimeMirrorDrainer(options = {}) {
  return new RealtimeMirrorDrainer(options);
}

module.exports = {
  createRealtimeMirrorDrainer,
  RealtimeMirrorDrainer,
};
