const requestCalls = [];

let executeImpl = async () => ({ output: {} });

const createRequest = () => {
  const request = {
    input: jest.fn().mockReturnThis(),
    output: jest.fn().mockReturnThis(),
    execute: jest.fn((procedure) => executeImpl(procedure)),
  };
  requestCalls.push(request);
  return request;
};

const poolInstance = {
  request: jest.fn(() => createRequest()),
  on: jest.fn(),
  close: jest.fn(),
  connected: true,
};

const connectMock = jest.fn().mockResolvedValue(poolInstance);

const ConnectionPool = jest.fn(() => ({
  connect: connectMock,
  on: poolInstance.on,
}));

module.exports = {
  ConnectionPool,
  NVarChar: jest.fn(() => 'NVarChar'),
  Bit: jest.fn(() => 'Bit'),
  Int: jest.fn(() => 'Int'),
  VarChar: jest.fn(() => 'VarChar'),
  __setExecuteImpl(impl) {
    executeImpl = impl;
  },
  __getRequests() {
    return requestCalls;
  },
  __getPool() {
    return poolInstance;
  },
  __reset() {
    requestCalls.length = 0;
    executeImpl = async () => ({ output: {} });
    poolInstance.request.mockClear();
    poolInstance.on.mockClear();
    poolInstance.close.mockClear();
    poolInstance.connected = true;
    connectMock.mockClear();
  },
};

// Delegate to shared test support mock while satisfying Jest's requirement for at least one test.
const mock = require('../../test_support/mssql-mock');

test.skip('mssql support mock placeholder (support)', () => {
  expect(mock).toBeDefined();
});

module.exports = mock;
