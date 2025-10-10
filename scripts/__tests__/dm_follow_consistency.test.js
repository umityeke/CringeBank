const { main } = require('../dm_follow_consistency');
const fixture = require('../testdata/follow_consistency_fixture');

function createMockFirestore(fixture) {
  return {
    collection(collectionName) {
      if (collectionName !== 'follows') {
        throw new Error(`Unexpected collection: ${collectionName}`);
      }
      return {
        doc(follower) {
          return {
            collection(subCollection) {
              if (subCollection !== 'targets') {
                throw new Error(`Unexpected subcollection: ${subCollection}`);
              }
              return {
                doc(target) {
                  return {
                    async get() {
                      const key = `${follower}/${target}`;
                      const doc = fixture.followFirestore[key] || null;
                      return {
                        exists: Boolean(doc),
                        data: () => (doc ? { ...doc } : undefined),
                      };
                    },
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

function createMockPool(recordset) {
  return {
    request() {
      return {
        input: jest.fn().mockReturnThis(),
        async query() {
          return { recordset };
        },
      };
    },
  };
}

describe('dm_follow_consistency main', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('produces summary for follow checks using fixtures', async () => {
    const pool = createMockPool(fixture.followSqlRows);
    const firestore = createMockFirestore(fixture);

    const consoleLog = jest.spyOn(console, 'log').mockImplementation(() => {});
    const consoleInfo = jest.spyOn(console, 'info').mockImplementation(() => {});
    const consoleWarn = jest.spyOn(console, 'warn').mockImplementation(() => {});
    const consoleError = jest.spyOn(console, 'error').mockImplementation(() => {});

    const summary = await main({
      checks: new Set(['follow']),
      limit: 10,
      output: 'json',
      verbose: false,
      firestore,
      pool,
      setExitCode: false,
    });

    expect(summary.follow.checked).toBe(2);
    expect(summary.follow.mismatches).toHaveLength(1);
    expect(summary.follow.missingFirestore).toHaveLength(1);

    const jsonCall = consoleLog.mock.calls.find((call) =>
      typeof call[0] === 'string' && call[0].includes('"follow"')
    );
    expect(jsonCall).toBeDefined();
    const parsedOutput = JSON.parse(jsonCall[0]);
    expect(parsedOutput.follow.checked).toBe(2);
    expect(parsedOutput.follow.missingFirestore.length).toBe(1);

    consoleLog.mockRestore();
    consoleInfo.mockRestore();
    consoleWarn.mockRestore();
    consoleError.mockRestore();
  });
});
