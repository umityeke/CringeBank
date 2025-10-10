module.exports = {
  followSqlRows: [
    {
      FollowerUserId: 'alice',
      TargetUserId: 'bob',
      State: 'ACTIVE',
      Source: 'cloudfunction://mirror',
      CreatedAt: '2025-02-01T10:00:00.000Z',
      UpdatedAt: '2025-02-01T11:00:00.000Z',
    },
    {
      FollowerUserId: 'charlie',
      TargetUserId: 'diana',
      State: 'PENDING',
      Source: 'cloudfunction://mirror',
      CreatedAt: '2025-02-02T10:00:00.000Z',
      UpdatedAt: '2025-02-02T11:00:00.000Z',
    },
  ],
  followFirestore: {
    'alice/bob': {
      status: 'ACTIVE',
      source: 'flutter://follow-service',
      createdAt: '2025-02-01T10:00:00.000Z',
      updatedAt: '2025-02-01T11:00:00.000Z',
    },
    // Intentionally missing charlie/diana to simulate drift.
  },
};
