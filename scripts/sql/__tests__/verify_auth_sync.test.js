const { buildComparison } = require('../verify_auth_sync');

describe('buildComparison', () => {
  it('Firebase kullanıcılarını SQL tarafında eksik olarak saptar', () => {
    const firebaseUsers = [
      { uid: 'uid-1', email: 'one@test.dev', disabled: false, createdAt: '2025-10-07T00:00:00Z' },
      { uid: 'uid-2', email: 'two@test.dev', disabled: false, createdAt: '2025-10-07T00:00:00Z' },
    ];
    const sqlRecords = [
      { authUid: 'uid-2', userId: 42, email: 'two@test.dev', username: 'two', dateCreated: '2025-10-05' },
    ];

    const result = buildComparison({ firebaseUsers, sqlRecords });

    expect(result.missingInSql).toHaveLength(1);
    expect(result.missingInSql[0]).toMatchObject({ uid: 'uid-1', email: 'one@test.dev' });
    expect(result.missingInFirebase).toHaveLength(0);
  });

  it('SQL kayıtlarını Firebase tarafında eksik olarak saptar', () => {
    const firebaseUsers = [{ uid: 'uid-1', email: 'one@test.dev', disabled: false, createdAt: '2025-10-07T00:00:00Z' }];
    const sqlRecords = [
      { authUid: 'uid-1', userId: 41, email: 'one@test.dev', username: 'one', dateCreated: '2025-10-05' },
      { authUid: 'uid-9', userId: 99, email: 'ghost@test.dev', username: 'ghost', dateCreated: '2025-10-01' },
    ];

    const result = buildComparison({ firebaseUsers, sqlRecords });

    expect(result.missingInFirebase).toHaveLength(1);
    expect(result.missingInFirebase[0]).toMatchObject({ uid: 'uid-9', userId: 99 });
    expect(result.missingInSql).toHaveLength(0);
  });

  it('SQL auth_uid değerlerindeki boşlukları kırpar', () => {
    const firebaseUsers = [{ uid: 'trim-this', email: 'trim@test.dev', disabled: false, createdAt: '2025-10-07T00:00:00Z' }];
    const sqlRecords = [
      { authUid: ' trim-this ', userId: 7, email: 'trim@test.dev', username: 'trim', dateCreated: '2025-09-30' },
    ];

    const result = buildComparison({ firebaseUsers, sqlRecords });

    expect(result.missingInSql).toHaveLength(0);
    expect(result.missingInFirebase).toHaveLength(0);
  });
});
