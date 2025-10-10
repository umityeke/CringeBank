jest.mock('firebase-functions', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  },
}));

jest.mock('@azure/service-bus', () => {
  const mockCompleteMessage = jest.fn(() => Promise.resolve());
  const mockAbandonMessage = jest.fn(() => Promise.resolve());
  const mockCloseReceiver = jest.fn(() => Promise.resolve());
  const mockCloseClient = jest.fn(() => Promise.resolve());

  const mockCreateReceiver = jest.fn(() => ({
    receiveMessages: jest.fn(),
    completeMessage: mockCompleteMessage,
    abandonMessage: mockAbandonMessage,
    close: mockCloseReceiver,
  }));

  const ServiceBusClient = jest.fn(() => ({
    createReceiver: mockCreateReceiver,
    close: mockCloseClient,
  }));

  ServiceBusClient.__mocks = {
    mockCompleteMessage,
    mockAbandonMessage,
    mockCloseReceiver,
    mockCloseClient,
    mockCreateReceiver,
  };

  return { ServiceBusClient };
});

jest.mock('../../sql_gateway/pool', () => ({
  getPool: jest.fn(async () => ({
    request() {
      return {
        input() {
          return this;
        },
        execute: jest.fn().mockResolvedValue({}),
      };
    },
  })),
}));

const mockExecuteProcedure = jest.fn(async () => {});
const mockResolveProcedureForEvent = jest.fn(() => 'sp_Example');

jest.mock('../processor', () => ({
  executeProcedure: mockExecuteProcedure,
  resolveProcedureForEvent: mockResolveProcedureForEvent,
}));

const { ServiceBusClient } = require('@azure/service-bus');
const { getPool } = require('../../sql_gateway/pool');
const serviceBusMocks = ServiceBusClient.__mocks;
const { createRealtimeMirrorDrainer } = require('../drainer');

function mockReceiveSequences(sequences) {
  const receiverCall = ServiceBusClient.__mocks.mockCreateReceiver.mock.results.at(-1);
  const receiver = receiverCall?.value;
  if (!receiver) {
    throw new Error('Receiver mock not initialized');
  }
  const queue = [...sequences];
  receiver.receiveMessages.mockImplementation(() => {
    const batch = queue.shift() || [];
    return Promise.resolve(batch);
  });
}

function createMessage(type, id = `msg-${Math.random().toString(16).slice(2)}`) {
  return {
    messageId: id,
    body: { type, data: { operation: 'update' } },
  };
}

describe('RealtimeMirrorDrainer', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env.SERVICEBUS_CONNECTION_STRING = 'Endpoint=sb://example/;SharedAccessKeyName=test;SharedAccessKey=abc=';
  mockExecuteProcedure.mockReset();
  mockExecuteProcedure.mockResolvedValue(undefined);
  mockResolveProcedureForEvent.mockReset();
  mockResolveProcedureForEvent.mockImplementation(() => 'sp_Example');
  serviceBusMocks.mockCompleteMessage.mockClear();
  serviceBusMocks.mockAbandonMessage.mockClear();
  serviceBusMocks.mockCreateReceiver.mockClear();
  });

  it('drains messages and completes them on success', async () => {
    const msgA = createMessage('dm.message.update', 'msg-a');
    const msgB = createMessage('dm.conversation.update', 'msg-b');

    const drainer = createRealtimeMirrorDrainer({
      config: {
        serviceBus: {
          connectionString: process.env.SERVICEBUS_CONNECTION_STRING,
          topicName: 'realtime-mirror',
          publishRetryCount: 3,
          subscriptions: {
            sqlWriter: 'sql-writer',
          },
        },
        sqlProcedures: {
          dmMessageUpsert: 'sp_StoreMirror_UpsertDmMessage',
          dmConversationUpsert: 'sp_StoreMirror_UpsertDmConversation',
        },
      },
      batchSize: 5,
      maxDurationMs: 5000,
      waitTimeMs: 10,
      maxIdleRounds: 0,
    });

    mockReceiveSequences([[msgA, msgB], []]);

    const stats = await drainer.drain();

    expect(stats.processed).toBe(2);
    expect(stats.completed).toBe(2);
    expect(stats.abandoned).toBe(0);
  expect(serviceBusMocks.mockCompleteMessage).toHaveBeenCalledTimes(2);
  expect(serviceBusMocks.mockAbandonMessage).not.toHaveBeenCalled();
    await drainer.close();
  });

  it('abandons messages when execution fails', async () => {
    const error = new Error('boom');
  mockExecuteProcedure.mockRejectedValueOnce(error);

    const drainer = createRealtimeMirrorDrainer({
      config: {
        serviceBus: {
          connectionString: process.env.SERVICEBUS_CONNECTION_STRING,
          topicName: 'realtime-mirror',
          publishRetryCount: 3,
          subscriptions: {
            sqlWriter: 'sql-writer',
          },
        },
        sqlProcedures: {
          followEdgeUpsert: 'sp_StoreMirror_UpsertFollowEdge',
        },
      },
      batchSize: 1,
      maxDurationMs: 2000,
      waitTimeMs: 10,
      maxIdleRounds: 0,
    });

    mockReceiveSequences([[createMessage('follow.edge.update', 'msg-c')], []]);

    const stats = await drainer.drain();

    expect(stats.processed).toBe(1);
    expect(stats.abandoned).toBe(1);
  expect(serviceBusMocks.mockAbandonMessage).toHaveBeenCalledTimes(1);
    await drainer.close();
  });

  it('skips unknown messages', async () => {
  mockResolveProcedureForEvent.mockReturnValueOnce(null);

    const drainer = createRealtimeMirrorDrainer({
      config: {
        serviceBus: {
          connectionString: process.env.SERVICEBUS_CONNECTION_STRING,
          topicName: 'realtime-mirror',
          publishRetryCount: 3,
          subscriptions: {
            sqlWriter: 'sql-writer',
          },
        },
        sqlProcedures: {},
      },
      batchSize: 1,
      maxDurationMs: 2000,
      waitTimeMs: 10,
      maxIdleRounds: 0,
    });

    mockReceiveSequences([[createMessage('unknown.event', 'msg-d')], []]);

    const stats = await drainer.drain();

    expect(stats.skipped).toBe(1);
  expect(serviceBusMocks.mockCompleteMessage).toHaveBeenCalled();
    await drainer.close();
  });
});
