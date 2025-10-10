// Delegate to shared test support mock while satisfying Jest's requirement for at least one test.
const mock = require('../test_support/mssql-mock');

test.skip('mssql support mock placeholder', () => {
  expect(mock).toBeDefined();
});

module.exports = mock;
