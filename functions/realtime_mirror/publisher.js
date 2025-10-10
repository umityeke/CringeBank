const functions = require('../regional_functions');
const { buildDmMessageEvent, buildDmConversationEvent, buildFollowEdgeEvent } = require('./event_builder');
const { publishEvent } = require('./service_bus');

async function handleDmMessageChange(change, context) {
  const event = buildDmMessageEvent(change, context);
  if (!event) {
    return null;
  }

  await publishEvent(event);
  functions.logger.info('realtimeMirror.dm_message_published', {
    messageId: event.data.messageId,
    conversationId: event.data.conversationId,
    eventId: event.id,
    operation: event.data.operation,
  });

  return event;
}

async function handleDmConversationChange(change, context) {
  const event = buildDmConversationEvent(change, context);
  if (!event) {
    return null;
  }

  await publishEvent(event);
  functions.logger.info('realtimeMirror.dm_conversation_published', {
    conversationId: event.data.conversationId,
    eventId: event.id,
    operation: event.data.operation,
  });

  return event;
}

async function handleFollowEdgeChange(change, context) {
  const event = buildFollowEdgeEvent(change, context);
  if (!event) {
    return null;
  }

  await publishEvent(event);
  functions.logger.info('realtimeMirror.follow_edge_published', {
    userId: event.data.userId,
    targetId: event.data.targetId,
    eventId: event.id,
    operation: event.data.operation,
  });

  return event;
}

module.exports = {
  handleDmMessageChange,
  handleDmConversationChange,
  handleFollowEdgeChange,
};
