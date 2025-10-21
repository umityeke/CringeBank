jest.mock('firebase-admin', () => require('../test_support/firebase-admin-mock'));

const admin = require('firebase-admin');
const fft = require('firebase-functions-test')();
const storeFunctions = require('../cringe_store_functions');

const escrowLock = fft.wrap(storeFunctions.escrowLock);

describe('cringe store sql adapter', () => {
  beforeEach(() => {
    if (typeof storeFunctions.__resetStoreGatewayTestOverrides === 'function') {
      storeFunctions.__resetStoreGatewayTestOverrides();
    }
    if (typeof admin.__reset === 'function') {
      admin.__reset();
    }
  });

  afterAll(() => {
    fft.cleanup();
  });

  it('delegates escrow lock to sql gateway with normalized payload', async () => {
    const executeProcedure = jest.fn(async () => ({ orderId: 'order-99' }));
    const getProcedure = jest.fn(() => ({
      requireAppCheck: false,
      parseInput: (input) => input,
    }));

    storeFunctions.__setStoreGatewayTestOverrides({
      executeProcedure,
      getProcedure,
      useSqlEscrowGateway: true,
    });

    const result = await escrowLock(
      { productId: '  prod-42  ', commissionRate: 12, isSystemOverride: true },
      { auth: { uid: 'buyer-1', token: { superadmin: true } }, app: {} }
    );

    expect(result).toEqual({ ok: true, orderId: 'order-99' });
    expect(getProcedure).toHaveBeenCalledWith('storeCreateOrder');
    expect(executeProcedure).toHaveBeenCalledTimes(1);
    expect(executeProcedure.mock.calls[0][0]).toBe('storeCreateOrder');
    expect(executeProcedure.mock.calls[0][1]).toMatchObject({
      productId: 'prod-42',
      commissionRate: 12,
      requestedBy: 'buyer-1',
      isSystemOverride: true,
    });
    expect(executeProcedure.mock.calls[0][2]).toMatchObject({ auth: { uid: 'buyer-1' } });
  });

  it('rejects when procedure definition is missing', async () => {
    storeFunctions.__setStoreGatewayTestOverrides({
      getProcedure: () => undefined,
      useSqlEscrowGateway: true,
    });

    await expect(
      escrowLock({ productId: 'p-1' }, { auth: { uid: 'buyer-1' }, app: {} })
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'sql_gateway_definition_missing',
    });
  });

  it('requires app check when procedure demands it', async () => {
    storeFunctions.__setStoreGatewayTestOverrides({
      getProcedure: () => ({ requireAppCheck: true }),
      useSqlEscrowGateway: true,
    });

    await expect(
      escrowLock({ productId: 'p-2' }, { auth: { uid: 'buyer-2' } })
    ).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'app_check_required',
    });
  });

  it('falls back to firestore handler when sql gateway disabled', async () => {
    const testHooks = storeFunctions.__test || {};
    const withSqlGateway = testHooks.withSqlGateway;
    if (typeof withSqlGateway !== 'function') {
      throw new Error('withSqlGateway test hook unavailable');
    }

    storeFunctions.__setStoreGatewayTestOverrides({
      useSqlEscrowGateway: false,
    });

    const sqlHandler = jest.fn();
    const firestoreHandler = jest.fn().mockResolvedValue({ ok: true });

    const result = await withSqlGateway('escrowLock', sqlHandler, firestoreHandler, {
      auth: { uid: 'buyer-3' },
    });

    expect(sqlHandler).not.toHaveBeenCalled();
    expect(firestoreHandler).toHaveBeenCalledTimes(1);
    expect(result).toEqual({ ok: true });
  });
});
