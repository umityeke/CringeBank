jest.mock('firebase-admin', () => {
  const store = new Map();

  const clone = (value) => {
    if (value === undefined) {
      return undefined;
    }
    return JSON.parse(JSON.stringify(value));
  };

  const applyUpdates = (target, updates) => {
    Object.entries(updates).forEach(([path, value]) => {
      const segments = path.split('.');
      let cursor = target;
      for (let i = 0; i < segments.length - 1; i += 1) {
        const segment = segments[i];
        if (cursor[segment] == null || typeof cursor[segment] !== 'object') {
          cursor[segment] = {};
        }
        cursor = cursor[segment];
      }
      cursor[segments[segments.length - 1]] = value;
    });
  };

  const createDocRef = (pathSegments) => {
    const fullPath = pathSegments.join('/');
    const docId = pathSegments[pathSegments.length - 1];

    const docRef = {
      id: docId,
      path: fullPath,
      async get() {
        const data = store.get(fullPath);
        return {
          exists: data != null,
          data: () => clone(data) || {},
        };
      },
      set(data) {
        store.set(fullPath, clone(data));
      },
      update(updates) {
        const current = clone(store.get(fullPath)) || {};
        applyUpdates(current, updates);
        store.set(fullPath, current);
      },
      collection(subCollection) {
        return createCollection([...pathSegments, subCollection]);
      },
    };

    return docRef;
  };

  const createCollection = (pathSegments) => ({
    doc(docId) {
      const generatedId = docId || `auto_${Math.random().toString(36).slice(2, 10)}`;
      return createDocRef([...pathSegments, generatedId]);
    },
  });

  const FieldValue = {
    serverTimestamp: () => ({ __type: 'serverTimestamp' }),
    increment: (value) => ({ __type: 'increment', value }),
  };

  const Timestamp = {
    fromMillis: (ms) => ({
      toMillis: () => ms,
      toDate: () => new Date(ms),
    }),
  };

  const firestoreInstance = {
    collection: (name) => createCollection([name]),
    runTransaction: async (updateFunction) => {
      const transaction = {
        async get(docRef) {
          return docRef.get();
        },
        set(docRef, data) {
          docRef.set(data);
        },
        update(docRef, updates) {
          docRef.update(updates);
        },
      };
      return updateFunction(transaction);
    },
    FieldValue,
    Timestamp,
  };

  const storageInstance = {
    bucket: () => ({
      file: () => ({
        delete: jest.fn().mockResolvedValue(undefined),
      }),
    }),
  };

  const firestoreFn = () => firestoreInstance;
  firestoreFn.FieldValue = FieldValue;
  firestoreFn.Timestamp = Timestamp;

  return {
    firestore: firestoreFn,
    storage: () => storageInstance,
    __store: store,
    __reset() {
      store.clear();
    },
    __getDoc(path) {
      return clone(store.get(path));
    },
  };
});

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
