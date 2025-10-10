const {
  backfillFollowEdges,
} = require('../sql/backfill_follow_edges');

function createMockFirestore(fixtures) {
  return {
    collection(collectionName) {
      if (collectionName !== 'follows') {
        throw new Error(`Unexpected collection: ${collectionName}`);
      }
      return {
        doc(followerId) {
          return {
            collection(subCollection) {
              if (subCollection !== 'targets') {
                throw new Error(`Unexpected subcollection: ${subCollection}`);
              }
              return {
                async get() {
                  const entries = Object.entries(fixtures[followerId] || {});
                  return {
                    empty: entries.length === 0,
                    docs: entries.map(([targetId, data]) => ({
                      id: targetId,
                      data: () => ({ ...data }),
                    })),
                  };
                },
              };
            },
          };
        },
      };
    },
  };
}

function createMockPool(outcomes = []) {
  const cursor = { index: 0 };
  return {
    request() {
      return {
        input: jest.fn().mockReturnThis(),
        async query() {
          const outcome = outcomes[cursor.index] || outcomes[outcomes.length - 1] || 'updated';
          cursor.index += 1;
          if (outcome instanceof Error) {
            throw outcome;
          }
          return { recordset: [{ Outcome: outcome }] };
        },
      };
    },
  };
}

describe('backfill_follow_edges', () => {
  it('runs in dry-run mode without SQL pool', async () => {
    const firestore = createMockFirestore({
      alice: {
        bob: { status: 'active', createdAt: '2025-01-01T00:00:00Z', updatedAt: '2025-01-02T00:00:00Z' },
      },
    });

    const stats = await backfillFollowEdges({
      firestore,
      dryRun: true,
      batchSize: 10,
      iterateFollowers: async function* () {
        yield 'alice';
      },
    });

    expect(stats.processed).toBe(1);
    expect(stats.inserted).toBe(0);
    expect(stats.updated).toBe(0);
    expect(stats.failures).toBe(0);
  });

  it('upserts follow edges into SQL', async () => {
    const firestore = createMockFirestore({
      alice: {
        bob: { status: 'ACTIVE', createdAt: '2025-01-01T00:00:00Z', updatedAt: '2025-01-01T10:00:00Z' },
        carol: { status: 'pending', source: 'mobile', createdAt: '2025-01-02T00:00:00Z' },
      },
    });
    const pool = createMockPool(['inserted', 'updated']);

    const stats = await backfillFollowEdges({
      firestore,
      pool,
      dryRun: false,
      batchSize: 5,
      iterateFollowers: async function* () {
        yield 'alice';
      },
    });

    expect(stats.processed).toBe(2);
    expect(stats.inserted).toBe(1);
    expect(stats.updated).toBe(1);
    expect(stats.failures).toBe(0);
  });

  it('records failures and respects strict mode', async () => {
    const firestore = createMockFirestore({
      alice: {
        bob: { status: 'active', createdAt: '2025-01-01T00:00:00Z' },
      },
    });
    const error = new Error('SQL error');
    const pool = createMockPool([error]);

    // Non-strict should capture failure and continue
    const stats = await backfillFollowEdges({
      firestore,
      pool,
      dryRun: false,
      batchSize: 5,
      stopAtFirstError: false,
      iterateFollowers: async function* () {
        yield 'alice';
      },
    });

    expect(stats.failures).toBe(1);

    // Strict mode should throw
    await expect(
      backfillFollowEdges({
        firestore,
        pool: createMockPool([error]),
        dryRun: false,
        batchSize: 5,
        stopAtFirstError: true,
        iterateFollowers: async function* () {
          yield 'alice';
        },
      })
    ).rejects.toThrow('SQL error');
  });
});
