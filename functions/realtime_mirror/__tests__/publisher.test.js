jest.mock('../../regional_functions', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  },
}));

const mockPublishEvent = jest.fn();

jest.mock('../service_bus', () => ({
  publishEvent: jest.fn((event) => mockPublishEvent(event)),
}));

const mockEventBuilders = {
  buildDmMessageEvent: jest.fn(),
  buildDmConversationEvent: jest.fn(),
  buildFollowEdgeEvent: jest.fn(),
};

jest.mock('../event_builder', () => mockEventBuilders);

const {
  handleDmMessageChange,
  handleDmConversationChange,
  handleFollowEdgeChange,
} = require('../publisher');

const change = { before: {}, after: {} };
const context = { params: {}, eventId: 'evt', timestamp: new Date().toISOString() };

beforeEach(() => {
  jest.clearAllMocks();
  mockPublishEvent.mockReset();
  mockEventBuilders.buildDmMessageEvent.mockReset();
  mockEventBuilders.buildDmConversationEvent.mockReset();
  mockEventBuilders.buildFollowEdgeEvent.mockReset();
});

describe('publisher handlers', () => {
  it('handleDmMessageChange skips publish when builder returns null', async () => {
  mockEventBuilders.buildDmMessageEvent.mockReturnValue(null);

    await handleDmMessageChange(change, context);

  expect(mockPublishEvent).not.toHaveBeenCalled();
  });

  it('handleDmMessageChange publishes built event', async () => {
    const event = { id: 'evt-1', type: 'dm.message.create', data: { conversationId: 'c1' } };
  mockEventBuilders.buildDmMessageEvent.mockReturnValue(event);

    await handleDmMessageChange(change, context);

  expect(mockPublishEvent).toHaveBeenCalledWith(event);
  });

  it('handleDmConversationChange publishes event', async () => {
    const event = { id: 'evt-2', type: 'dm.conversation.update', data: { conversationId: 'c1' } };
  mockEventBuilders.buildDmConversationEvent.mockReturnValue(event);

    await handleDmConversationChange(change, context);

  expect(mockPublishEvent).toHaveBeenCalledWith(event);
  });

  it('handleFollowEdgeChange publishes event', async () => {
    const event = { id: 'evt-3', type: 'follow.edge.create', data: { userId: 'u1' } };
  mockEventBuilders.buildFollowEdgeEvent.mockReturnValue(event);

    await handleFollowEdgeChange(change, context);

  expect(mockPublishEvent).toHaveBeenCalledWith(event);
  });
});
