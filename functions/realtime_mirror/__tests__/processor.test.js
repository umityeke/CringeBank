jest.mock('firebase-functions', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  },
}));

jest.mock('@azure/service-bus', () => ({
  ServiceBusClient: jest.fn(() => ({
    createReceiver: jest.fn(() => ({ subscribe: jest.fn() })),
    close: jest.fn(),
  })),
}));

const mockNVarChar = jest.fn((length) => `NVARCHAR(${length})`);

jest.mock('mssql', () => ({
  NVarChar: jest.fn((length) => `NVARCHAR(${length})`),
  DateTimeOffset: 'DateTimeOffset',
  MAX: -1,
}));

const mssql = require('mssql');

const {
  resolveProcedureForEvent,
  executeProcedure,
} = require('../processor');

describe('resolveProcedureForEvent', () => {
  const procedures = {
    dmMessageUpsert: 'sp_StoreMirror_UpsertDmMessage',
    dmConversationUpsert: 'sp_StoreMirror_UpsertDmConversation',
    dmMessageDelete: 'sp_StoreMirror_DeleteDmMessage',
    followEdgeUpsert: 'sp_StoreMirror_UpsertFollowEdge',
    followEdgeDelete: 'sp_StoreMirror_DeleteFollowEdge',
  };

  const cases = [
    ['dm.message.create', 'sp_StoreMirror_UpsertDmMessage'],
    ['dm.message.update', 'sp_StoreMirror_UpsertDmMessage'],
    ['dm.message.delete', 'sp_StoreMirror_DeleteDmMessage'],
    ['dm.conversation.create', 'sp_StoreMirror_UpsertDmConversation'],
    ['dm.conversation.update', 'sp_StoreMirror_UpsertDmConversation'],
    ['follow.edge.create', 'sp_StoreMirror_UpsertFollowEdge'],
    ['follow.edge.update', 'sp_StoreMirror_UpsertFollowEdge'],
    ['follow.edge.delete', 'sp_StoreMirror_DeleteFollowEdge'],
    ['unknown.event', null],
  ];

  test.each(cases)('maps %s to %s', (eventType, expected) => {
    const result = resolveProcedureForEvent({ type: eventType }, procedures);
    expect(result).toBe(expected);
  });
});

describe('executeProcedure', () => {
  it('binds event payload to stored procedure inputs', async () => {
    const inputs = [];
    const executeSpy = jest.fn().mockResolvedValue({});

    const pool = {
      request() {
        return {
          input(name, type, value) {
            inputs.push({ name, type, value });
            return this;
          },
          execute: executeSpy,
        };
      },
    };

    const event = {
      id: 'evt-123',
      type: 'follow.edge.update',
      source: 'firestore://follows/alice/targets/bob',
      time: '2025-01-01T12:00:00.000Z',
      data: {
        operation: 'update',
        userId: 'alice',
        targetId: 'bob',
        document: { status: 'ACTIVE' },
        previousDocument: { status: 'PENDING' },
      },
    };

    await executeProcedure(pool, 'sp_StoreMirror_UpsertFollowEdge', event);

    expect(executeSpy).toHaveBeenCalledWith('sp_StoreMirror_UpsertFollowEdge');

    const byName = Object.fromEntries(inputs.map((entry) => [entry.name, entry]));

    expect(byName.EventType.value).toBe('follow.edge.update');
    expect(byName.EventType.type).toBe('NVARCHAR(64)');

    expect(byName.Operation.value).toBe('update');
    expect(byName.Operation.type).toBe('NVARCHAR(32)');

    expect(byName.Source.value).toBe(event.source);
    expect(byName.Source.type).toBe('NVARCHAR(256)');

    expect(byName.EventId.value).toBe(event.id);
    expect(byName.EventId.type).toBe('NVARCHAR(128)');

    expect(byName.EventTimestamp.value).toBeInstanceOf(Date);
    expect(byName.EventTimestamp.value.toISOString()).toBe('2025-01-01T12:00:00.000Z');

    expect(JSON.parse(byName.DocumentJson.value)).toEqual({ status: 'ACTIVE' });
    expect(JSON.parse(byName.PreviousDocumentJson.value)).toEqual({ status: 'PENDING' });

    const metadata = JSON.parse(byName.MetadataJson.value);
    expect(metadata.userId).toBe('alice');
    expect(metadata.targetId).toBe('bob');
    expect(metadata.operation).toBe('update');

    // Ensure types were computed via mocked mssql helpers
    expect(mssql.NVarChar).toHaveBeenCalledWith(64);
    expect(mssql.NVarChar).toHaveBeenCalledWith(32);
    expect(mssql.NVarChar).toHaveBeenCalledWith(256);
    expect(mssql.NVarChar).toHaveBeenCalledWith(128);
  });
});
