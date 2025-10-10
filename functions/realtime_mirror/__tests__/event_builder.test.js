jest.mock('../../regional_functions', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  },
}));

const { Timestamp } = require('firebase-admin/firestore');
const {
  buildDmMessageEvent,
  buildDmConversationEvent,
  buildFollowEdgeEvent,
} = require('../event_builder');

function makeChange({ before, after }) {
  return {
    before: before
      ? {
          exists: true,
          data: () => before,
        }
      : { exists: false, data: () => null },
    after: after
      ? {
          exists: true,
          data: () => after,
        }
      : { exists: false, data: () => null },
  };
}

describe('event_builder', () => {
  const context = {
    eventId: 'evt-123',
    timestamp: '2025-01-01T00:00:00.000Z',
    params: {
      conversationId: 'convo-1',
      messageId: 'msg-1',
      userId: 'user-1',
      targetId: 'target-1',
    },
  };

  it('buildDmMessageEvent emits create event with serialized payload', () => {
    const change = makeChange({
      before: null,
      after: {
        text: 'hello',
        sentAt: new Date('2025-01-01T00:00:00.000Z'),
        viewedAt: Timestamp.fromDate(new Date('2025-01-02T00:00:00.000Z')),
      },
    });

    const event = buildDmMessageEvent(change, context);

    expect(event).toMatchObject({
      type: 'dm.message.create',
      data: {
        conversationId: 'convo-1',
        messageId: 'msg-1',
        operation: 'create',
        document: {
          text: 'hello',
          sentAt: '2025-01-01T00:00:00.000Z',
          viewedAt: '2025-01-02T00:00:00.000Z',
        },
        previousDocument: null,
      },
    });
  });

  it('buildDmMessageEvent returns null when update is effectively no-op', () => {
    const payload = {
      text: 'hello',
      sentAt: Timestamp.fromDate(new Date('2025-01-01T00:00:00.000Z')),
    };
    const change = makeChange({ before: payload, after: payload });

    const event = buildDmMessageEvent(change, context);

    expect(event).toBeNull();
  });

  it('buildDmConversationEvent emits delete when document removed', () => {
    const change = makeChange({ before: { ownerId: 'user-1' }, after: null });

    const event = buildDmConversationEvent(change, context);

    expect(event).toMatchObject({
      type: 'dm.conversation.delete',
      data: {
        operation: 'delete',
        conversationId: 'convo-1',
        document: null,
        previousDocument: { ownerId: 'user-1' },
      },
    });
  });

  it('buildFollowEdgeEvent emits update payload with serialized timestamps', () => {
    const before = {
      followedAt: Timestamp.fromDate(new Date('2025-01-01T00:00:00.000Z')),
      status: 'ACTIVE',
    };
    const after = {
      followedAt: Timestamp.fromDate(new Date('2025-01-01T00:00:00.000Z')),
      status: 'BLOCKED',
    };
    const change = makeChange({ before, after });

    const event = buildFollowEdgeEvent(change, context);

    expect(event).toMatchObject({
      type: 'follow.edge.update',
      data: {
        operation: 'update',
        userId: 'user-1',
        targetId: 'target-1',
        document: {
          followedAt: '2025-01-01T00:00:00.000Z',
          status: 'BLOCKED',
        },
        previousDocument: {
          followedAt: '2025-01-01T00:00:00.000Z',
          status: 'ACTIVE',
        },
      },
    });
  });
});
