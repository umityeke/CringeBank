jest.mock('firebase-functions', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  },
}));

jest.mock('@azure/service-bus', () => {
  const sendMessages = jest.fn(() => Promise.resolve());
  const closeSender = jest.fn(() => Promise.resolve());
  const createSender = jest.fn(() => ({
    sendMessages,
    close: closeSender,
  }));
  const closeClient = jest.fn(() => Promise.resolve());
  const client = {
    createSender,
    close: closeClient,
  };
  const ServiceBusClient = jest.fn(() => client);

  return {
    ServiceBusClient,
    __mocks: {
      sendMessages,
      createSender,
      closeSender,
      closeClient,
      client,
    },
  };
});

const { __mocks } = require('@azure/service-bus');

const ORIGINAL_ENV = { ...process.env };

describe('service_bus.publishEvent', () => {
  let publishEvent;
  let shutdown;

  beforeEach(() => {
    process.env = { ...ORIGINAL_ENV };
    process.env.SERVICEBUS_CONNECTION_STRING = 'Endpoint=sb://test/;SharedAccessKeyName=test;SharedAccessKey=abc=';
    process.env.SERVICEBUS_TOPIC_REALTIME_MIRROR = 'test-topic';
    process.env.SERVICEBUS_PUBLISH_RETRY = '3';

  jest.clearAllMocks();
  __mocks.sendMessages.mockClear();
  __mocks.createSender.mockClear();
  __mocks.closeSender.mockClear();
  __mocks.closeClient.mockClear();

    delete require.cache[require.resolve('../service_bus')];
    ({ publishEvent, shutdown } = require('../service_bus'));
  });

  afterEach(async () => {
    await shutdown();
    jest.clearAllMocks();
    process.env = { ...ORIGINAL_ENV };
  });

  function buildEvent(overrides = {}) {
    return {
      id: 'evt-1',
      type: 'dm.message.create',
      source: 'firestore://conversations/convo-1/messages/msg-1',
      data: {
        conversationId: 'convo-1',
        messageId: 'msg-1',
        operation: 'create',
      },
      ...overrides,
    };
  }

  it('sends CloudEvent payload with metadata', async () => {
    const event = buildEvent();

    await publishEvent(event);

    expect(__mocks.createSender).toHaveBeenCalledWith('test-topic');
    expect(__mocks.sendMessages).toHaveBeenCalledWith(
      expect.objectContaining({
        body: event,
        contentType: 'application/json',
        subject: event.type,
        messageId: event.id,
        correlationId: event.data.conversationId,
        applicationProperties: {
          source: event.source,
          operation: event.data.operation,
        },
      }),
    );
  });

  it('retries transient failures before succeeding', async () => {
    const event = buildEvent();
    const transient = new Error('transient');
    __mocks.sendMessages.mockRejectedValueOnce(transient).mockResolvedValueOnce();

    await publishEvent(event);

    expect(__mocks.sendMessages).toHaveBeenCalledTimes(2);
  });

  it('reuses cached sender for subsequent publishes', async () => {
    const event = buildEvent();

    await publishEvent(event);
    await publishEvent(event);

    expect(__mocks.createSender).toHaveBeenCalledTimes(1);
    expect(__mocks.sendMessages).toHaveBeenCalledTimes(2);
  });
});
