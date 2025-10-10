jest.mock('firebase-functions', () => {
  class HttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }

  const regionMock = jest.fn(() => ({
    https: {
      onCall: (handler) => handler,
    },
  }));

  return {
    region: regionMock,
    logger: {
      info: jest.fn(),
      error: jest.fn(),
      warn: jest.fn(),
    },
    https: {
      onCall: (handler) => handler,
      HttpsError,
    },
  };
});

jest.mock('../rbac', () => {
  const assertAllowed = jest.fn(() => Promise.resolve());
  return {
    PolicyEvaluator: {
      fromEnv: jest.fn(() => ({ assertAllowed })),
    },
  };
});

jest.mock('../sql_gateway/pool', () => ({
  getPool: jest.fn(),
  resetPool: jest.fn(),
}));

jest.mock(
  'mssql',
  () => ({
    NVarChar: jest.fn(() => 'NVarChar'),
    Int: jest.fn(() => 'Int'),
    Bit: jest.fn(() => 'Bit'),
  }),
  { virtual: true }
);

describe('sql_gateway callable', () => {
  const functions = require('firebase-functions');
  const { createCallableProcedure, executeProcedure } = require('../sql_gateway/callable');
  const { mapSqlErrorToHttps } = require('../sql_gateway/errors');
  const { PolicyEvaluator } = require('../rbac');
  const { getPool } = require('../sql_gateway/pool');

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('executes ensureUser procedure successfully', async () => {
    const executeMock = jest.fn().mockResolvedValue({
      output: {
        UserId: 42,
        Created: true,
      },
    });

    const requestMock = jest.fn(() => ({
      input: jest.fn().mockReturnThis(),
      output: jest.fn().mockReturnThis(),
      execute: executeMock,
    }));

    getPool.mockResolvedValue({
      request: requestMock,
    });

    const handler = createCallableProcedure('ensureUser');
    const response = await handler(
      {
        username: 'ExampleUser',
        email: 'user@example.com',
      },
      {
        auth: { uid: 'uid-123', token: { email: 'user@example.com' } },
        app: { appId: 'sample' },
      }
    );

    expect(PolicyEvaluator.fromEnv).toHaveBeenCalledTimes(1);
    expect(executeMock).toHaveBeenCalledWith('dbo.sp_EnsureUser');
    expect(response).toEqual({
      ok: true,
      data: {
        userId: 42,
        created: true,
      },
    });

    expect(functions.logger.info).toHaveBeenNthCalledWith(
      1,
      'sqlGateway.attempt',
      expect.objectContaining({ key: 'ensureUser', payloadKeys: expect.arrayContaining(['authUid', 'username', 'email']) })
    );
    expect(functions.logger.info).toHaveBeenNthCalledWith(
      2,
      'sqlGateway.success',
      expect.objectContaining({ key: 'ensureUser', outputKeys: expect.arrayContaining(['UserId', 'Created']) })
    );
  });

  it('translates sql errors to HttpsError', async () => {
    const error = new Error('login failed');
    error.code = 'ELOGIN';
    const mapped = mapSqlErrorToHttps(error);
    expect(mapped).toBeInstanceOf(Error);
    expect(mapped.code).toBe('failed-precondition');
  });

  it('rejects when username is missing', async () => {
    const handler = createCallableProcedure('ensureUser');
    await expect(
      handler(
        { email: 'missing@username.test' },
        { auth: { uid: 'uid-456', token: { email: 'missing@username.test' } }, app: { appId: 'sample' } }
      )
    ).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('maps sql errors when using executeProcedure directly', async () => {
    const error = new Error('login failed');
    error.code = 'ELOGIN';
    getPool.mockRejectedValueOnce(error);

    await expect(
      executeProcedure('ensureUser', { username: 'X', email: 'x@example.com' }, { auth: { uid: 'uid-999' } })
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});