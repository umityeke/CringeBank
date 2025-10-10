const store = new Map();

const clone = (value) => {
  if (value === undefined) {
    return undefined;
  }
  return JSON.parse(JSON.stringify(value));
};

const mergeDeep = (target, source) => {
  const output = { ...target };
  Object.entries(source).forEach(([key, value]) => {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      output[key] = mergeDeep(output[key] && typeof output[key] === 'object' ? output[key] : {}, value);
    } else {
      output[key] = value;
    }
  });
  return output;
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
        id: docId,
        data: () => clone(data) || {},
      };
    },
    set(data, options) {
      const cloned = clone(data) || {};
      if (options && options.merge) {
        const current = clone(store.get(fullPath)) || {};
        store.set(fullPath, mergeDeep(current, cloned));
      } else {
        store.set(fullPath, cloned);
      }
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

class MockTimestamp {
  constructor(dateInput) {
    if (dateInput instanceof Date) {
      this._date = new Date(dateInput.getTime());
    } else if (typeof dateInput === 'number') {
      this._date = new Date(dateInput);
    } else {
      this._date = new Date();
    }
  }

  toMillis() {
    return this._date.getTime();
  }

  toDate() {
    return new Date(this._date.getTime());
  }
}

MockTimestamp.fromMillis = (ms) => new MockTimestamp(ms);
MockTimestamp.fromDate = (date) => new MockTimestamp(date);

const Timestamp = MockTimestamp;

const firestoreInstance = {
  collection: (name) => createCollection([name]),
  runTransaction: async (updateFunction) => {
    const transaction = {
      async get(docRef) {
        return docRef.get();
      },
      set(docRef, data, options) {
        docRef.set(data, options);
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

const authInstance = {
  getUser: jest.fn(),
  getUserByEmail: jest.fn(),
  getUserByPhoneNumber: jest.fn(),
  setCustomUserClaims: jest.fn(),
  updateUser: jest.fn(),
};

module.exports = {
  firestore: firestoreFn,
  storage: () => storageInstance,
  auth: () => authInstance,
  initializeApp: jest.fn(),
  __store: store,
  __reset() {
    store.clear();
  },
  __getDoc(path) {
    return clone(store.get(path));
  },
  __setDoc(path, data) {
    store.set(path, clone(data));
  },
};
