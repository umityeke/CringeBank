// Delegate to shared test support mock while satisfying Jest's requirement for at least one test.
const mock = require('../../test_support/firebase-admin-mock');

test.skip('firebase admin support mock placeholder (support)', () => {
  expect(mock).toBeDefined();
});

module.exports = mock;
