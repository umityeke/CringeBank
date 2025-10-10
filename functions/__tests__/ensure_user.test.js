jest.mock('firebase-admin', () => require('../test_support/firebase-admin-mock'));
jest.mock('../sql_gateway', () => ({
  executeProcedure: jest.fn(),
}));

const admin = require('firebase-admin');
const fft = require('firebase-functions-test')();
const { executeProcedure } = require('../sql_gateway');

const originalEnv = { ...process.env };

process.env.SQLSERVER_HOST = 'localhost';
process.env.SQLSERVER_USER = 'test-user';
process.env.SQLSERVER_PASS = 'test-pass';
process.env.SQLSERVER_DB = 'test-db';
process.env.ENSURE_SQL_USER_REGION = 'europe-west1';

// Require after environment variables are prepared.
const { createEnsureSqlUserHandler } = require('../ensure_user');

const wrapEnsureSqlUser = () => {
  const handler = createEnsureSqlUserHandler(admin);
  return fft.wrap(handler);
};

describe('ensureSqlUser callable', () => {
  beforeEach(() => {
    admin.__reset();
  executeProcedure.mockReset();
  });

  afterAll(() => {
    fft.cleanup();
    Object.assign(process.env, originalEnv);
  });

  const baseContext = {
    auth: {
      uid: 'user-123',
      token: {
        email: 'user@example.com',
        email_verified: true,
      },
    },
    app: {
      appId: 'demo-app',
    },
  };

  it('creates SQL user and seeds default profile data when procedure reports created', async () => {
    executeProcedure.mockResolvedValue({
      userId: 4242,
      created: true,
    });

    const ensureSqlUser = wrapEnsureSqlUser();

    const payload = {
      username: 'CringeLord',
      displayName: 'Cringe Lord',
      email: 'user@example.com',
      avatar: '😎',
    };

    const response = await ensureSqlUser(payload, baseContext);

    expect(response).toEqual(
      expect.objectContaining({
        sqlUserId: 4242,
        created: true,
        profile: expect.objectContaining({
          id: 'user-123',
          uid: 'user-123',
          authUid: 'user-123',
          sqlUserId: 4242,
          username: 'CringeLord',
          fullName: 'Cringe Lord',
          email: 'user@example.com',
          rozetler: ['Yeni Üye'],
        }),
      }),
    );

    const stored = admin.__getDoc('users/user-123');
    expect(stored).toMatchObject({
      uid: 'user-123',
      sqlUserId: 4242,
      username: 'CringeLord',
      usernameLower: 'cringelord',
      fullName: 'Cringe Lord',
      email: 'user@example.com',
      emailLower: 'user@example.com',
      rozetler: ['Yeni Üye'],
      isPremium: false,
      followersCount: 0,
      followingCount: 0,
    });
    expect(Array.isArray(stored.searchKeywords)).toBe(true);
    expect(stored.searchKeywords.length).toBeGreaterThan(0);
    expect(stored.avatar).toBe('😎');

    expect(executeProcedure).toHaveBeenCalledWith(
      'ensureUser',
      {
        authUid: 'user-123',
        email: 'user@example.com',
        username: 'CringeLord',
        displayName: 'Cringe Lord',
      },
      expect.objectContaining({ auth: baseContext.auth }),
    );
  });

  it('merges profile without overriding existing fields when SQL user already exists', async () => {
    admin.__setDoc('users/user-123', {
      rozetler: ['Efsane'],
      coins: 120,
      createdAt: '2021-01-01T00:00:00.000Z',
    });

    executeProcedure.mockResolvedValue({
      userId: 555,
      created: false,
    });

    const ensureSqlUser = wrapEnsureSqlUser();

    const payload = {
      username: 'CringeLord',
      displayName: 'Cringe Lord II',
      email: 'user@example.com',
      avatar: '🦄',
    };

    const response = await ensureSqlUser(payload, baseContext);

    expect(response.created).toBe(false);
    expect(response.sqlUserId).toBe(555);
    expect(response.profile).toMatchObject({
      id: 'user-123',
      rozetler: ['Efsane'],
      coins: 120,
      sqlUserId: 555,
      fullName: 'Cringe Lord II',
      avatar: '🦄',
    });

    const stored = admin.__getDoc('users/user-123');
    expect(stored.rozetler).toEqual(['Efsane']);
    expect(stored.createdAt).toBe('2021-01-01T00:00:00.000Z');
    expect(stored.fullName).toBe('Cringe Lord II');
    expect(stored.sqlUserId).toBe(555);
    expect(stored.lastActive).toEqual(expect.objectContaining({ __type: 'serverTimestamp' }));
  });

  it('rejects when App Check token missing', async () => {
    executeProcedure.mockResolvedValue({
      userId: 1,
      created: true,
    });

    const ensureSqlUser = wrapEnsureSqlUser();

    await expect(
      ensureSqlUser({ username: 'User', email: 'user@example.com' }, {
        auth: baseContext.auth,
      }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});
