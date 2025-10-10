const crypto = require('crypto');
const functions = require('firebase-functions');
const { serializeDocument } = require('./serializer');

function documentsEqual(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

function generateEventId(eventType, source, contextEventId) {
  const entropy = crypto.randomBytes(8).toString('hex');
  return `${eventType}:${source}:${contextEventId}:${entropy}`;
}

function buildBaseEvent({ change, context, type, source }) {
  const eventId = generateEventId(type, source, context.eventId || crypto.randomUUID?.() || 'evt');
  const nowIso = new Date().toISOString();

  return {
    id: eventId,
    type,
    source,
    specversion: '1.0',
    time: nowIso,
    data: {
      eventId: context.eventId || null,
      timestamp: context.timestamp || nowIso,
      params: context.params || {},
      operation: null,
      document: null,
      previousDocument: null,
    },
  };
}

function resolveOperation(change) {
  const beforeExists = Boolean(change.before && change.before.exists);
  const afterExists = Boolean(change.after && change.after.exists);

  if (!beforeExists && afterExists) {
    return 'create';
  }
  if (beforeExists && afterExists) {
    return 'update';
  }
  if (beforeExists && !afterExists) {
    return 'delete';
  }
  return 'unknown';
}

function buildDmMessageEvent(change, context) {
  const { conversationId, messageId } = context.params;
  const source = `firestore://conversations/${conversationId}/messages/${messageId}`;
  const operation = resolveOperation(change);

  if (operation === 'unknown') {
    functions.logger.debug('dmMirror.ignore_unknown_operation', {
      conversationId,
      messageId,
      eventId: context.eventId,
    });
    return null;
  }

  const event = buildBaseEvent({
    change,
    context,
    type: `dm.message.${operation}`,
    source,
  });

  event.data.operation = operation;
  event.data.conversationId = conversationId;
  event.data.messageId = messageId;
  const document = serializeDocument(change.after);
  const previousDocument = serializeDocument(change.before);

  if (operation === 'update' && documentsEqual(previousDocument, document)) {
    return null;
  }

  event.data.document = document;
  event.data.previousDocument = previousDocument;

  if (event.data.document) {
    event.data.documentSource = 'firestore';
  }
  if (event.data.previousDocument) {
    event.data.previousDocumentSource = 'firestore';
  }

  return event;
}

function buildDmConversationEvent(change, context) {
  const { conversationId } = context.params;
  const source = `firestore://conversations/${conversationId}`;
  const operation = resolveOperation(change);

  if (operation === 'unknown') {
    functions.logger.debug('dmConversationMirror.ignore_unknown_operation', {
      conversationId,
      eventId: context.eventId,
    });
    return null;
  }

  const event = buildBaseEvent({
    change,
    context,
    type: `dm.conversation.${operation}`,
    source,
  });

  event.data.operation = operation;
  event.data.conversationId = conversationId;
  const document = serializeDocument(change.after);
  const previousDocument = serializeDocument(change.before);

  if (operation === 'update' && documentsEqual(previousDocument, document)) {
    return null;
  }

  event.data.document = document;
  event.data.previousDocument = previousDocument;

  return event;
}

function buildFollowEdgeEvent(change, context) {
  const { userId, targetId } = context.params;
  const source = `firestore://follows/${userId}/targets/${targetId}`;
  const operation = resolveOperation(change);

  if (operation === 'unknown') {
    functions.logger.debug('followMirror.ignore_unknown_operation', {
      userId,
      targetId,
      eventId: context.eventId,
    });
    return null;
  }

  const event = buildBaseEvent({
    change,
    context,
    type: `follow.edge.${operation}`,
    source,
  });

  event.data.operation = operation;
  event.data.userId = userId;
  event.data.targetId = targetId;
  const document = serializeDocument(change.after);
  const previousDocument = serializeDocument(change.before);

  if (operation === 'update' && documentsEqual(previousDocument, document)) {
    return null;
  }

  event.data.document = document;
  event.data.previousDocument = previousDocument;

  return event;
}

module.exports = {
  buildDmMessageEvent,
  buildDmConversationEvent,
  buildFollowEdgeEvent,
};
