const { resolveProcedureForEvent } = require('../realtime_mirror/processor');

jest.mock('../realtime_mirror/service_bus', () => ({
  publishEvent: jest.fn().mockResolvedValue(undefined),
}));

const { publishEvent } = require('../realtime_mirror/service_bus');
const {
  handleDmMessageChange,
  handleDmConversationChange,
  handleFollowEdgeChange,
} = require('../realtime_mirror/publisher');

const mockTimestamp = {
  toDate: () => new Date('2025-10-08T00:00:00.000Z'),
};

function buildChange(beforeDoc, afterDoc) {
  return {
    before: beforeDoc
      ? {
          exists: true,
          data: () => beforeDoc,
        }
      : { exists: false, data: () => null },
    after: afterDoc
      ? {
          exists: true,
          data: () => afterDoc,
        }
      : { exists: false, data: () => null },
  };
}

const baseContext = {
  eventId: 'evt-123',
  timestamp: '2025-10-08T12:00:00.000Z',
  params: {},
};

describe('realtime mirror publisher', () => {
  beforeEach(() => {
    publishEvent.mockClear();
  });

  test('publishes create event for DM message', async () => {
    const change = buildChange(null, {
      text: 'Hello',
      createdAt: mockTimestamp,
      authorId: 'userA',
    });

    const context = {
      ...baseContext,
      params: { conversationId: 'userA_userB', messageId: 'msg1' },
    };

    await handleDmMessageChange(change, context);

    expect(publishEvent).toHaveBeenCalledTimes(1);
    const event = publishEvent.mock.calls[0][0];
    expect(event.type).toBe('dm.message.create');
    expect(event.data.operation).toBe('create');
    expect(event.data.document).toMatchObject({
      text: 'Hello',
      authorId: 'userA',
      createdAt: '2025-10-08T00:00:00.000Z',
    });
  });

  test('publishes delete event for follow edge removal', async () => {
    const change = buildChange(
      {
        state: 'accepted',
        createdAt: mockTimestamp,
      },
      null,
    );

    const context = {
      ...baseContext,
      params: { userId: 'userA', targetId: 'userB' },
    };

    await handleFollowEdgeChange(change, context);

    expect(publishEvent).toHaveBeenCalledTimes(1);
    const event = publishEvent.mock.calls[0][0];
    expect(event.type).toBe('follow.edge.delete');
    expect(event.data.operation).toBe('delete');
    expect(event.data.previousDocument).toMatchObject({
      state: 'accepted',
      createdAt: '2025-10-08T00:00:00.000Z',
    });
  });

  test('ignores no-op conversation change', async () => {
    const snapshot = {
      exists: true,
      data: () => ({ lastMessageAt: mockTimestamp }),
    };

    const context = {
      ...baseContext,
      params: { conversationId: 'userA_userB' },
    };

    await handleDmConversationChange(
      {
        before: snapshot,
        after: snapshot,
      },
      context,
    );

    expect(publishEvent).not.toHaveBeenCalled();
  });
});

describe('resolveProcedureForEvent', () => {
  const sqlProcedures = {
    dmMessageUpsert: 'sp_StoreMirror_UpsertDmMessage',
    dmConversationUpsert: 'sp_StoreMirror_UpsertDmConversation',
    dmMessageDelete: 'sp_StoreMirror_DeleteDmMessage',
    followEdgeUpsert: 'sp_StoreMirror_UpsertFollowEdge',
    followEdgeDelete: 'sp_StoreMirror_DeleteFollowEdge',
  };

  test('routes DM message create events to upsert proc', () => {
    const procedure = resolveProcedureForEvent({ type: 'dm.message.create' }, sqlProcedures);
    expect(procedure).toBe('sp_StoreMirror_UpsertDmMessage');
  });

  test('routes follow delete', () => {
    const procedure = resolveProcedureForEvent({ type: 'follow.edge.delete' }, sqlProcedures);
    expect(procedure).toBe('sp_StoreMirror_DeleteFollowEdge');
  });

  test('returns null for unknown event type', () => {
    const procedure = resolveProcedureForEvent({ type: 'something.else' }, sqlProcedures);
    expect(procedure).toBeNull();
  });
});
