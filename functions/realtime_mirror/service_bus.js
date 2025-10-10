const { ServiceBusClient } = require('@azure/service-bus');
const functions = require('../regional_functions');
const { readRealtimeMirrorConfig } = require('./config');

let sender = null;
let senderTopicName = null;
let client = null;

function ensureSender(topicName) {
  if (sender && senderTopicName === topicName) {
    return sender;
  }

  if (!client) {
    const config = readRealtimeMirrorConfig();
    client = new ServiceBusClient(config.serviceBus.connectionString);
  }

  if (sender) {
    sender.close().catch((error) => {
      functions.logger.warn('realtimeMirror.sender_close_failed', error);
    });
  }

  senderTopicName = topicName;
  sender = client.createSender(topicName);
  return sender;
}

async function publishEvent(event) {
  const config = readRealtimeMirrorConfig();
  const sbSender = ensureSender(config.serviceBus.topicName);

  const message = {
    body: event,
    contentType: 'application/json',
    subject: event.type,
    messageId: event.id,
    correlationId: event.data?.conversationId || event.data?.userId || event.id,
    applicationProperties: {
      source: event.source,
      operation: event.data?.operation,
    },
  };

  try {
    const retryCount = Math.max(config.serviceBus.publishRetryCount || 1, 1);
    let attempt = 0;

    // Simple retry loop with exponential backoff (100ms base)
    while (true) {
      try {
        await sbSender.sendMessages(message);
        return;
      } catch (error) {
        attempt += 1;
        if (attempt >= retryCount) {
          throw error;
        }
        const delayMs = 100 * 2 ** (attempt - 1);
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
  } catch (error) {
    functions.logger.error('realtimeMirror.publish_failed', {
      error: error?.message,
      type: event.type,
      source: event.source,
      operation: event.data?.operation,
      eventId: event.id,
    });
    throw error;
  }
}

async function shutdown() {
  const operations = [];
  if (sender) {
    operations.push(
      sender.close().catch((error) => functions.logger.warn('realtimeMirror.sender_shutdown_failed', error)),
    );
    sender = null;
  }
  if (client) {
    operations.push(
      client.close().catch((error) => functions.logger.warn('realtimeMirror.client_shutdown_failed', error)),
    );
    client = null;
  }
  await Promise.allSettled(operations);
}

module.exports = {
  publishEvent,
  shutdown,
};
