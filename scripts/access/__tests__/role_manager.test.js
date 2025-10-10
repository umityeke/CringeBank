const {
  normalizeRole,
  updateClaims,
  buildFirestoreUpdates,
  createRoleManager,
} = require('../role_manager');

describe('normalizeRole', () => {
  test('desteklenen rolleri normalize eder', () => {
    expect(normalizeRole('superadmin')).toBe('superadmin');
    expect(normalizeRole('Super-Admin')).toBe('superadmin');
    expect(normalizeRole('system-writer')).toBe('system_writer');
  });

  test('geçersiz rol için hata fırlatır', () => {
    expect(() => normalizeRole('boss')).toThrow('Desteklenmeyen rol');
  });
});

describe('updateClaims', () => {
  test('superadmin rolünü atar ve kaldırır', () => {
    const granted = updateClaims({}, 'superadmin', true);
    expect(granted).toMatchObject({
      admin: true,
      superadmin: true,
      role: 'superadmin',
    });

    const revoked = updateClaims(granted, 'superadmin', false);
    expect(revoked.admin).toBeUndefined();
    expect(revoked.superadmin).toBeUndefined();
    expect(revoked.role).toBeUndefined();
  });

  test('system_writer rolünü atar ve kaldırır', () => {
    const granted = updateClaims({}, 'system_writer', true);
    expect(granted.system_writer).toBe(true);
    expect(granted.backend).toBe(true);

    const revoked = updateClaims(granted, 'system_writer', false);
    expect(revoked.system_writer).toBeUndefined();
    expect(revoked.backend).toBeUndefined();
  });
});

describe('buildFirestoreUpdates', () => {
  test('FieldValue.serverTimestamp çağırır ve alanları üretir', () => {
    const serverTimestamp = jest.fn(() => 'SERVER_TS');
    const FieldValue = { serverTimestamp };

    const updates = buildFirestoreUpdates('superadmin', true, FieldValue);

    expect(serverTimestamp).toHaveBeenCalledTimes(1);
    expect(updates).toMatchObject({
      updatedAt: 'SERVER_TS',
      isSuperAdmin: true,
      'roles.superadmin': true,
    });
  });
});

describe('createRoleManager', () => {
  function buildMocks() {
    const userRecord = {
      uid: 'uid-123',
      email: 'test@example.com',
      customClaims: { existing: true },
    };

    const setCustomUserClaims = jest.fn();
    const listUsers = jest.fn().mockResolvedValue({ users: [], pageToken: undefined });
    const getUser = jest.fn().mockResolvedValue(userRecord);
    const getUserByEmail = jest.fn().mockResolvedValue(userRecord);

    const userDocSet = jest.fn();
    const usersDoc = { set: userDocSet };
    const usersCollection = { doc: jest.fn(() => usersDoc) };
    const auditAdd = jest.fn();
    const auditCollection = { add: auditAdd };

    const firestore = {
      collection: jest.fn((name) => {
        if (name === 'users') {
          return usersCollection;
        }
        if (name === 'admin_audit') {
          return auditCollection;
        }
        throw new Error(`Unexpected collection ${name}`);
      }),
    };

    const FieldValue = { serverTimestamp: jest.fn(() => 'ts') };

    return {
      userRecord,
      auth: { getUser, getUserByEmail, setCustomUserClaims, listUsers },
      firestore,
      FieldValue,
      userDocSet,
      auditAdd,
    };
  }

  test('dry-run sırasında hiçbir yazma işlemi yapılmaz', async () => {
    const mocks = buildMocks();
    const manager = createRoleManager({
      auth: mocks.auth,
      firestore: mocks.firestore,
      FieldValue: mocks.FieldValue,
    });

    const result = await manager.applyRole({
      email: 'test@example.com',
      role: 'superadmin',
      grant: true,
      dryRun: true,
      notes: 'review',
    });

    expect(mocks.auth.setCustomUserClaims).not.toHaveBeenCalled();
    expect(mocks.userDocSet).not.toHaveBeenCalled();
    expect(mocks.auditAdd).not.toHaveBeenCalled();
    expect(result.persisted).toBe(false);
    expect(result.newClaims.superadmin).toBe(true);
  });

  test('grant işlemi sırasında Auth, Firestore ve audit çağrılır', async () => {
    const mocks = buildMocks();
    const manager = createRoleManager({
      auth: mocks.auth,
      firestore: mocks.firestore,
      FieldValue: mocks.FieldValue,
    });

    const result = await manager.applyRole({
      uid: 'uid-123',
      role: 'system_writer',
      grant: true,
      notes: 'job',
      executedBy: 'tester',
    });

    expect(mocks.auth.setCustomUserClaims).toHaveBeenCalledWith(
      'uid-123',
      expect.objectContaining({ system_writer: true, backend: true }),
    );
    expect(mocks.userDocSet).toHaveBeenCalledWith(
      expect.objectContaining({ isSystemWriter: true }),
      { merge: true },
    );
    expect(mocks.auditAdd).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'grant:system_writer', executedBy: 'tester' }),
    );
    expect(result.persisted).toBe(true);
  });

  test('listRoles sadece yetkili kullanıcıları döndürür ve sıralar', async () => {
    const mocks = buildMocks();
    mocks.auth.listUsers.mockResolvedValue({
      users: [
        { uid: '2', email: 'b@example.com', displayName: 'B', customClaims: { system_writer: true } },
        { uid: '1', email: 'a@example.com', displayName: 'A', customClaims: {} },
        { uid: '3', email: 'c@example.com', displayName: 'C', customClaims: { superadmin: true } },
      ],
    });

    const manager = createRoleManager({
      auth: mocks.auth,
      firestore: mocks.firestore,
      FieldValue: mocks.FieldValue,
    });

    const results = await manager.listRoles();
    expect(results).toHaveLength(2);
    expect(results[0].email).toBe('b@example.com');
    expect(results[1].email).toBe('c@example.com');
  });
});
