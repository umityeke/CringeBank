const { Timestamp } = require('firebase-admin/firestore');

function serializeValue(value) {
  if (value === null || value === undefined) {
    return null;
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (value instanceof Timestamp) {
    return value.toDate().toISOString();
  }

  if (Array.isArray(value)) {
    return value.map((item) => serializeValue(item));
  }

  if (Buffer.isBuffer(value)) {
    return value.toString('base64');
  }

  if (typeof value === 'object') {
    if (typeof value.toDate === 'function') {
      try {
        const date = value.toDate();
        if (date instanceof Date) {
          return date.toISOString();
        }
      } catch (error) {
        // fall through to generic object serialization
      }
    }

    return Object.keys(value).reduce((acc, key) => {
      acc[key] = serializeValue(value[key]);
      return acc;
    }, {});
  }

  return value;
}

function serializeDocument(snapshot) {
  if (!snapshot) {
    return null;
  }

  const data = typeof snapshot.data === 'function' ? snapshot.data() : snapshot;
  if (!data) {
    return null;
  }

  return serializeValue(data);
}

module.exports = {
  serializeDocument,
  serializeValue,
};
