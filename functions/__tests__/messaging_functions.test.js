jest.mock('firebase-admin', () => require('../test_support/firebase-admin-mock'));

const messagingFunctions = require('../messaging_functions');
const admin = require('firebase-admin');
const fft = require('firebase-functions-test')();

const createConversation = fft.wrap(messagingFunctions.createConversation);
const sendMessage = fft.wrap(messagingFunctions.sendMessage);

describe('messaging functions', () => {
  beforeEach(() => {
    admin.__reset();
  });

  afterAll(() => {
    fft.cleanup();
  });

  it('creates a new conversation with metadata', async () => {
    const result = await createConversation({
      otherUserId: 'user-b',
      participantMeta: {
        'user-a': { displayName: 'Alice', username: 'alice' },
        'user-b': { displayName: 'Bob', username: 'bob' },
      },
    }, { auth: { uid: 'user-a' } });

    expect(result).toEqual({ conversationId: 'user-a_user-b', created: true });

    const conversation = admin.__getDoc('conversations/user-a_user-b');
    expect(conversation).toBeDefined();
    expect(conversation.members).toEqual(['user-a', 'user-b']);
    expect(conversation.participantMeta['user-a'].displayName).toBe('Alice');
    expect(conversation.participantMeta['user-b'].username).toBe('bob');
    expect(conversation.readPointers).toEqual({ 'user-a': null, 'user-b': null });
  expect(conversation.lastMessageId).toBeNull();
  });

  it('updates metadata when conversation already exists', async () => {
    await createConversation({ otherUserId: 'user-b' }, { auth: { uid: 'user-a' } });

    const second = await createConversation({
      otherUserId: 'user-b',
      participantMeta: {
        'user-b': { avatar: '😎' },
      },
    }, { auth: { uid: 'user-a' } });

    expect(second).toEqual({ conversationId: 'user-a_user-b', created: false });

    const conversation = admin.__getDoc('conversations/user-a_user-b');
    expect(conversation.participantMeta['user-b'].avatar).toBe('😎');
  });

  it('stores message and updates conversation summary', async () => {
    await createConversation({ otherUserId: 'user-b' }, { auth: { uid: 'user-a' } });

    const response = await sendMessage({
      conversationId: 'user-a_user-b',
      text: 'Merhaba',
      participantMeta: {
        'user-a': { displayName: 'Alice' },
      },
    }, { auth: { uid: 'user-a' } });

    expect(response.success).toBe(true);
    expect(response.messageId).toBeDefined();

    const conversation = admin.__getDoc('conversations/user-a_user-b');
    expect(conversation.lastMessageText).toBe('Merhaba');
    expect(conversation.lastSenderId).toBe('user-a');
  expect(conversation.lastMessageId).toBe(response.messageId);
    expect(conversation[`readPointers`]['user-a']).toBe(response.messageId);

    const message = admin.__getDoc(`conversations/user-a_user-b/messages/${response.messageId}`);
    expect(message.text).toBe('Merhaba');
    expect(message.senderId).toBe('user-a');
  });

  it('accepts client supplied message id', async () => {
    await createConversation({ otherUserId: 'user-b' }, { auth: { uid: 'user-a' } });

    const response = await sendMessage({
      conversationId: 'user-a_user-b',
      text: 'Selam',
      clientMessageId: 'client_abc123',
    }, { auth: { uid: 'user-a' } });

    expect(response.success).toBe(true);
    expect(response.messageId).toBe('client_abc123');

    const message = admin.__getDoc('conversations/user-a_user-b/messages/client_abc123');
    expect(message).toBeDefined();
    expect(message.text).toBe('Selam');
  });

  it('rejects duplicate client message id', async () => {
    await createConversation({ otherUserId: 'user-b' }, { auth: { uid: 'user-a' } });

    await sendMessage({
      conversationId: 'user-a_user-b',
      text: 'Merhaba',
      clientMessageId: 'client_dup999',
    }, { auth: { uid: 'user-a' } });

    await expect(sendMessage({
      conversationId: 'user-a_user-b',
      text: 'Tekrar',
      clientMessageId: 'client_dup999',
    }, { auth: { uid: 'user-a' } })).rejects.toMatchObject({
      code: 'already-exists',
    });
  });
});
