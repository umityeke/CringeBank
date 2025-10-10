'use strict';

const { main } = require('./dm_follow_consistency');
const fixture = require('./testdata/follow_consistency_fixture');

function createFirestore() {
  return {
    collection(collectionName) {
      if (collectionName !== 'follows') {
        throw new Error(`Unsupported collection ${collectionName}`);
      }
      return {
        doc(follower) {
          return {
            collection(subCollection) {
              if (subCollection !== 'targets') {
                throw new Error(`Unsupported subcollection ${subCollection}`);
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

function createPool() {
  return {
    request() {
      return {
        input: () => this,
        async query() {
          return { recordset: fixture.followSqlRows };
        },
      };
    },
  };
}

(async () => {
  const summary = await main({
    checks: new Set(['follow']),
    limit: 10,
    output: 'json',
    verbose: false,
    firestore: createFirestore(),
    pool: createPool(),
    setExitCode: false,
    silent: true,
  });

  console.log(JSON.stringify(summary, null, 2));
})().catch((err) => {
  console.error('Failed to generate fixture report', err);
  process.exitCode = 1;
});
