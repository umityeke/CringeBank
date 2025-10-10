const { ServiceBusClient } = require('@azure/service-bus');
const functions = require('firebase-functions');
const mssql = require('mssql');
const { readRealtimeMirrorConfig } = require('./config');
const { getPool } = require('../sql_gateway/pool');

function resolveProcedureForEvent(event, sqlProcedures) {
  switch (event.type) {
    case 'dm.message.create':
    case 'dm.message.update':
      return sqlProcedures.dmMessageUpsert;
    case 'dm.message.delete':
      return sqlProcedures.dmMessageDelete;
    case 'dm.conversation.create':
    case 'dm.conversation.update':
      return sqlProcedures.dmConversationUpsert;
    case 'follow.edge.create':
    case 'follow.edge.update':
      return sqlProcedures.followEdgeUpsert;
    case 'follow.edge.delete':
      return sqlProcedures.followEdgeDelete;
    default:
      return null;
  }
}

async function executeProcedure(pool, procedureName, event) {
  const request = pool.request();
  request.input('EventType', mssql.NVarChar(64), event.type);
  request.input('Operation', mssql.NVarChar(32), event.data?.operation ?? null);
  request.input('Source', mssql.NVarChar(256), event.source || null);
  request.input('EventId', mssql.NVarChar(128), event.id || null);
  request.input('EventTimestamp', mssql.DateTimeOffset, event.time ? new Date(event.time) : new Date());
  request.input('DocumentJson', mssql.NVarChar(mssql.MAX), JSON.stringify(event.data?.document ?? null));
  request.input(
    'PreviousDocumentJson',
    mssql.NVarChar(mssql.MAX),
    JSON.stringify(event.data?.previousDocument ?? null),
  );
  request.input('MetadataJson', mssql.NVarChar(mssql.MAX), JSON.stringify(event.data ?? {}));

  return request.execute(procedureName);
}

function createSqlWriterProcessor(options = {}) {
  const config = readRealtimeMirrorConfig();
  const connectionString = config.serviceBus.connectionString;
  const subscription = options.subscription || config.serviceBus.subscriptions.sqlWriter;
  const topic = options.topic || config.serviceBus.topicName;

  const client = new ServiceBusClient(connectionString);
  const receiver = client.createReceiver(topic, subscription, {
    receiveMode: 'peekLock',
    maxAutoLockRenewalDurationInMs: 5 * 60 * 1000,
  });

  async function handleMessage(message) {
    const event = message.body;
    if (!event || typeof event !== 'object') {
      functions.logger.warn('realtimeMirror.sqlWriter_invalid_message', {
        messageId: message.messageId,
      });
      await receiver.completeMessage(message);
      return;
    }

    const procedureName = resolveProcedureForEvent(event, config.sqlProcedures);
    if (!procedureName) {
      functions.logger.warn('realtimeMirror.sqlWriter_unknown_type', {
        type: event.type,
        messageId: message.messageId,
      });
      await receiver.completeMessage(message);
      return;
    }

    try {
      const pool = await getPool();
      await executeProcedure(pool, procedureName, event);
      await receiver.completeMessage(message);
      functions.logger.info('realtimeMirror.sqlWriter_processed', {
        messageId: message.messageId,
        type: event.type,
        procedure: procedureName,
      });
    } catch (error) {
      functions.logger.error('realtimeMirror.sqlWriter_failed', {
        messageId: message.messageId,
        type: event.type,
        procedure: procedureName,
        error: error?.message,
      });
      await receiver.abandonMessage(message, {
        reason: 'processing_error',
        error: error?.message,
      });
    }
  }

  async function handleError(error) {
    functions.logger.error('realtimeMirror.sqlWriter_receiver_error', {
      error: error?.message,
      stack: error?.stack,
    });
  }

  return {
    start() {
      receiver.subscribe({ processMessage: handleMessage, processError: handleError });
      functions.logger.info('realtimeMirror.sqlWriter_started', {
        topic,
        subscription,
      });
      return { receiver, client };
    },
    async stop() {
      await receiver.close();
      await client.close();
    },
  };
}

module.exports = {
  createSqlWriterProcessor,
  executeProcedure,
  resolveProcedureForEvent,
};
