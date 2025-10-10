jest.mock('firebase-functions', () => {
  class HttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }

  return {
    https: {
      HttpsError,
    },
    logger: {
      info: jest.fn(),
      error: jest.fn(),
      warn: jest.fn(),
    },
  };
});

jest.mock(
  'mssql',
  () => ({
    NVarChar: jest.fn(() => 'NVarChar'),
    Bit: jest.fn(() => 'Bit'),
    Decimal: jest.fn(() => 'Decimal'),
    Int: jest.fn(() => 'Int'),
    DateTimeOffset: 'DateTimeOffset',
    MAX: 'MAX',
  }),
  { virtual: true }
);

const { getProcedure, listProcedureKeys } = require('../sql_gateway/procedures');
const mssql = require('mssql');

describe('sql gateway procedures definitions', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('includes getUserProfile in registry', () => {
    expect(listProcedureKeys()).toEqual(expect.arrayContaining(['getUserProfile']));
  });

  it('includes store escrow procedures in registry', () => {
    expect(listProcedureKeys()).toEqual(
      expect.arrayContaining(['storeCreateOrder', 'storeReleaseEscrow', 'storeRefundEscrow', 'storeAdjustWallet'])
    );
  });

  it('includes store read procedures in registry', () => {
    expect(listProcedureKeys()).toEqual(
      expect.arrayContaining([
        'storeListProducts',
        'storeGetProduct',
        'storeGetWallet',
        'storeListOrdersForBuyer',
      ])
    );
  });

  it('includes dmSend procedure in registry', () => {
    expect(listProcedureKeys()).toEqual(
      expect.arrayContaining([
        'dmListConversations',
        'dmListMessages',
        'dmSend',
        'followGetRelationship',
        'followEdgeUpsert',
      ])
    );
  });

  it('includes followGetRelationship procedure in registry', () => {
    expect(listProcedureKeys()).toEqual(expect.arrayContaining(['followGetRelationship']));
  });

  describe('dmListConversations definition', () => {
    const definition = getProcedure('dmListConversations');

    it('requires authentication', () => {
      expect(() => definition.parseInput({}, {})).toThrow(
        expect.objectContaining({ code: 'unauthenticated' })
      );
    });

    it('parses payload with limit, cursor, and before conversation id', () => {
      const iso = new Date('2025-01-02T03:04:05.000Z').toISOString();
      const payload = definition.parseInput(
        {
          limit: 75,
          updatedBefore: '2025-01-02T03:04:05Z',
          beforeConversationId: ' convo-123 ',
        },
        { auth: { uid: ' user-001 ' } }
      );

      expect(payload).toEqual({
        authUid: 'user-001',
        limit: 75,
        updatedBeforeIso: iso,
        beforeConversationId: 'convo-123',
      });
    });

    it('clamps limit to maximum and binds SQL inputs', () => {
      const payload = definition.parseInput(
        { limit: 999 },
        { auth: { uid: 'auth-1' } }
      );

      expect(payload.limit).toBe(100);

      const request = {};
      request.input = jest.fn(function () {
        return request;
      });

      definition.bind(request, {
        ...payload,
        updatedBeforeIso: new Date('2025-01-01T00:00:00Z').toISOString(),
        beforeConversationId: 'abc',
      });

      expect(request.input).toHaveBeenCalledWith('AuthUid', expect.anything(), 'auth-1');
      expect(request.input).toHaveBeenCalledWith('Limit', expect.anything(), 100);

      const updatedCall = request.input.mock.calls.find((call) => call[0] === 'UpdatedBefore');
      expect(updatedCall).toBeTruthy();
      expect(updatedCall[2]).toBeInstanceOf(Date);
      expect(updatedCall[2].toISOString()).toBe('2025-01-01T00:00:00.000Z');

      const beforeIdCall = request.input.mock.calls.find(
        (call) => call[0] === 'BeforeConversationFirestoreId'
      );
      expect(beforeIdCall[2]).toBe('abc');
    });

    it('transforms SQL recordset into conversation objects', () => {
      const now = new Date('2025-01-05T10:00:00Z');
      const result = {
        recordset: [
          {
            ConversationFirestoreId: ' convo-1 ',
            ConversationKey: 'key-1',
            ConversationType: 'DIRECT',
            IsGroup: 0,
            MemberCount: 2,
            MetadataJson: '{"foo":"bar"}',
            ParticipantMetaJson: '{"user-1":{"displayName":"Test"}}',
            ReadPointersJson: '{"user-1":"msg-1"}',
            LastMessageFirestoreId: 'msg-123',
            LastMessageSenderId: 'user-2',
            LastMessagePreview: 'hello',
            LastMessageTimestamp: now,
            CreatedAt: new Date('2025-01-01T00:00:00Z'),
            UpdatedAt: new Date('2025-01-06T00:00:00Z'),
            LastEventId: 'evt-1',
            LastEventTimestamp: now,
            UserReadPointerMessageId: 'msg-1',
            UserReadPointerTimestamp: now,
            UserMetadataJson: '{"role":"member"}',
            ParticipantsJson: '[{"UserId":"user-1"}]',
          },
        ],
      };

      const transformed = definition.transform(result, {
        authUid: 'user-1',
        limit: 20,
      });

      expect(transformed.resultCount).toBe(1);
      expect(transformed.nextCursor).toBe(new Date('2025-01-06T00:00:00Z').toISOString());
      expect(transformed.nextConversationId).toBe('convo-1');
      expect(transformed.conversations[0]).toMatchObject({
        conversationId: 'convo-1',
        conversationKey: 'key-1',
        isGroup: false,
        memberCount: 2,
        metadata: { foo: 'bar' },
        participantMeta: { 'user-1': { displayName: 'Test' } },
        lastMessage: {
          messageId: 'msg-123',
          senderId: 'user-2',
          preview: 'hello',
        },
        myState: {
          readPointerMessageId: 'msg-1',
        },
      });
    });
  });

  describe('dmListMessages definition', () => {
    const definition = getProcedure('dmListMessages');

    it('requires auth and conversation id', () => {
      expect(() => definition.parseInput({}, {})).toThrow(
        expect.objectContaining({ code: 'unauthenticated' })
      );

      expect(() =>
        definition.parseInput({}, { auth: { uid: 'user' } })
      ).toThrow(expect.objectContaining({ code: 'invalid-argument' }));
    });

    it('parses pagination inputs and clamps limit', () => {
      const iso = new Date('2025-02-01T00:00:00Z').toISOString();
      const payload = definition.parseInput(
        {
          conversationId: ' convo-1 ',
          limit: 500,
          beforeTimestamp: '2025-02-01T00:00:00Z',
          beforeMessageId: ' message-9 ',
        },
        { auth: { uid: ' auth-2 ' } }
      );

      expect(payload).toEqual({
        authUid: 'auth-2',
        conversationId: 'convo-1',
        limit: 200,
        beforeTimestampIso: iso,
        beforeMessageId: 'message-9',
      });
    });

    it('binds SQL parameters including cursor fields', () => {
      const payload = {
        authUid: 'user-1',
        conversationId: 'convo-xyz',
        limit: 40,
        beforeTimestampIso: new Date('2025-01-10T10:00:00Z').toISOString(),
        beforeMessageId: 'msg-11',
      };

      const request = {};
      request.input = jest.fn(function () {
        return request;
      });

      definition.bind(request, payload);

      expect(request.input).toHaveBeenCalledWith('AuthUid', expect.anything(), 'user-1');
      expect(request.input).toHaveBeenCalledWith('ConversationFirestoreId', expect.anything(), 'convo-xyz');
      expect(request.input).toHaveBeenCalledWith('Limit', expect.anything(), 40);

      const beforeTimestampCall = request.input.mock.calls.find((call) => call[0] === 'BeforeTimestamp');
      expect(beforeTimestampCall[2]).toBeInstanceOf(Date);
      expect(beforeTimestampCall[2].toISOString()).toBe('2025-01-10T10:00:00.000Z');

      const beforeMessageCall = request.input.mock.calls.find((call) => call[0] === 'BeforeMessageFirestoreId');
      expect(beforeMessageCall[2]).toBe('msg-11');
    });

    it('transforms SQL messages result set', () => {
      const createdAt = new Date('2025-03-01T09:00:00Z');
      const result = {
        recordset: [
          {
            MessageFirestoreId: ' msg-1 ',
            ClientMessageId: ' client-1 ',
            AuthorUserId: ' writer-1 ',
            BodyText: 'hello sql',
            AttachmentJson: '[{"path":"/a"}]',
            ExternalMediaJson: '{"type":"link"}',
            DeletedForJson: '[]',
            TombstoneJson: 'null',
            CreatedAt: createdAt,
            UpdatedAt: createdAt,
            EditedAt: createdAt,
            EditedBy: ' editor ',
            DeletedAt: null,
            DeletedBy: null,
            Source: 'mirror',
            LastEventId: 'evt-1',
            LastEventTimestamp: createdAt,
          },
        ],
      };

      const transformed = definition.transform(result, {
        conversationId: 'convo-x',
        limit: 50,
      });

      expect(transformed.conversationId).toBe('convo-x');
      expect(transformed.messages).toHaveLength(1);
      expect(transformed.messages[0]).toMatchObject({
        messageId: 'msg-1',
        clientMessageId: 'client-1',
        authorUserId: 'writer-1',
        bodyText: 'hello sql',
        attachments: [{ path: '/a' }],
        externalMedia: { type: 'link' },
        editedBy: 'editor',
        source: 'mirror',
        lastEvent: {
          id: 'evt-1',
        },
      });
      expect(transformed.nextCursor).toBe(createdAt.toISOString());
      expect(transformed.nextMessageId).toBe('msg-1');
    });
  });

  describe('followGetRelationship definition', () => {
    const definition = getProcedure('followGetRelationship');

    it('requires authentication and matching viewer', () => {
      expect(() => definition.parseInput({}, {})).toThrow(
        expect.objectContaining({ code: 'unauthenticated' })
      );

      expect(() =>
        definition.parseInput({ viewerUid: 'viewer-2', targetUid: 'target-1' }, { auth: { uid: 'viewer-1' } })
      ).toThrow(expect.objectContaining({ code: 'permission-denied' }));
    });

    it('parses payload with fallback viewer and target validation', () => {
      const payload = definition.parseInput({ targetUid: ' target-9 ' }, { auth: { uid: ' viewer-7 ' } });

      expect(payload).toEqual({
        viewerUid: 'viewer-7',
        targetUid: 'target-9',
      });

      expect(() => definition.parseInput({}, { auth: { uid: 'viewer-1' } })).toThrow(
        expect.objectContaining({ code: 'invalid-argument' })
      );
    });

    it('binds SQL parameters for viewer and target', () => {
      const request = {
        input: jest.fn(function () {
          return request;
        }),
      };

      definition.bind(request, {
        viewerUid: 'viewer-1',
        targetUid: 'target-2',
      });

  expect(request.input).toHaveBeenCalledWith('ViewerUserId', 'NVarChar', 'viewer-1');
  expect(request.input).toHaveBeenCalledWith('TargetUserId', 'NVarChar', 'target-2');
    });

    it('transforms SQL records into relationship edges', () => {
      const createdAt = new Date('2025-04-01T12:00:00Z');
      const blockCreatedAt = new Date('2025-04-02T10:00:00Z');
      const result = {
        recordset: [
          {
            Direction: 'OUTGOING',
            FollowerUserId: 'viewer-1 ',
            TargetUserId: ' target-1',
            EdgeId: 'edge-123',
            State: 'accepted',
            Source: 'MIRROR',
            CreatedAt: createdAt,
            UpdatedAt: createdAt,
            LastEventId: 'evt-1',
            LastEventTimestamp: createdAt,
            MetadataJson: '{"note":"out"}',
          },
          {
            Direction: 'INCOMING',
            FollowerUserId: 'target-1',
            TargetUserId: 'viewer-1',
            State: 'pending',
            Source: 'mirror',
            CreatedAt: createdAt,
            UpdatedAt: createdAt,
            LastEventId: null,
            LastEventTimestamp: createdAt,
            MetadataJson: '{"note":"in"}',
          },
        ],
        recordsets: [
          [
            {
              Direction: 'OUTGOING',
              FollowerUserId: 'viewer-1 ',
              TargetUserId: ' target-1',
              EdgeId: 'edge-123',
              State: 'accepted',
              Source: 'MIRROR',
              CreatedAt: createdAt,
              UpdatedAt: createdAt,
              LastEventId: 'evt-1',
              LastEventTimestamp: createdAt,
              MetadataJson: '{"note":"out"}',
            },
            {
              Direction: 'INCOMING',
              FollowerUserId: 'target-1',
              TargetUserId: 'viewer-1',
              State: 'pending',
              Source: 'mirror',
              CreatedAt: createdAt,
              UpdatedAt: createdAt,
              LastEventId: null,
              LastEventTimestamp: createdAt,
              MetadataJson: '{"note":"in"}',
            },
          ],
          [
            {
              Direction: 'OUTGOING',
              UserId: 'viewer-1 ',
              TargetUserId: ' target-1',
              CreatedAt: blockCreatedAt,
              RevokedAt: null,
              Source: 'mirror',
              MetadataJson: '{"reason":"mute"}',
            },
            {
              Direction: 'INCOMING',
              UserId: 'target-1',
              TargetUserId: 'viewer-1',
              CreatedAt: blockCreatedAt,
              RevokedAt: null,
              MetadataJson: null,
            },
          ],
        ],
      };

      const transformed = definition.transform(result, {
        viewerUid: 'viewer-1',
        targetUid: 'target-1',
      });

      expect(transformed.relationship).toBeDefined();
      expect(transformed.relationship.outgoing).toMatchObject({
        id: 'edge-123',
        srcUid: 'viewer-1',
        dstUid: 'target-1',
        status: 'ACCEPTED',
        metadata: { note: 'out' },
      });
      expect(transformed.relationship.incoming).toMatchObject({
        id: 'target-1_viewer-1',
        status: 'PENDING',
        metadata: { note: 'in' },
      });
      expect(transformed.relationship.outgoingBlock).toMatchObject({
        id: 'viewer-1_target-1',
        srcUid: 'viewer-1',
        dstUid: 'target-1',
        metadata: { reason: 'mute' },
      });
      expect(transformed.relationship.incomingBlock).toMatchObject({
        id: 'target-1_viewer-1',
        srcUid: 'target-1',
        dstUid: 'viewer-1',
      });
    });
  });

  describe('getUserProfile definition', () => {
    const definition = getProcedure('getUserProfile');

    it('parses authUid from payload or context', () => {
      const payloadContext = definition.parseInput({ authUid: '  UID-123  ' }, {});
      expect(payloadContext).toEqual({ authUid: 'UID-123' });

      const contextFallback = definition.parseInput({}, { auth: { uid: ' user-456 ' } });
      expect(contextFallback).toEqual({ authUid: 'user-456' });
    });

    it('throws when authUid is missing', () => {
      try {
        definition.parseInput({}, {});
        throw new Error('expected parseInput to throw');
      } catch (error) {
        expect(error).toMatchObject({ code: 'invalid-argument' });
      }
    });

    it('binds parameters for SQL request', () => {
      const inputs = [];
      const request = {
        input: jest.fn((name, type, value) => {
          inputs.push({ name, type, value });
          return request;
        }),
      };

      definition.bind(request, { authUid: 'USER-789' });

      expect(inputs).toEqual([
        {
          name: 'AuthUid',
          type: expect.anything(),
          value: 'USER-789',
        },
      ]);
    });

    it('transforms SQL result into profile object', () => {
      const now = new Date('2024-01-01T00:00:00.000Z');
      const result = {
        recordset: [
          {
            UserId: 99,
            AuthUid: 'user-789',
            Email: 'user@example.com',
            Username: 'example',
            DisplayName: 'Example User',
            CreatedAt: now,
            UpdatedAt: now,
          },
        ],
      };

      const transformed = definition.transform(result, { authUid: 'user-789' });

      expect(transformed).toEqual({
        userId: 99,
        authUid: 'user-789',
        email: 'user@example.com',
        username: 'example',
        displayName: 'Example User',
        createdAt: now.toISOString(),
        updatedAt: now.toISOString(),
      });
    });

    it('throws not-found when SQL returns empty set', () => {
      try {
        definition.transform({ recordset: [] }, { authUid: 'missing' });
        throw new Error('expected transform to throw');
      } catch (error) {
        expect(error).toMatchObject({ code: 'not-found' });
      }
    });
  });

  describe('storeCreateOrder definition', () => {
    const definition = getProcedure('storeCreateOrder');

    it('parses payload with defaults and overrides', () => {
      const payload = definition.parseInput(
        {
          productId: ' product-123 ',
          commissionRate: '0.075',
          override: 'true',
          requestedBy: '  system-user  ',
        },
        { auth: { uid: ' buyer-666 ' } }
      );

      expect(payload).toEqual({
        buyerAuthUid: 'buyer-666',
        productId: 'product-123',
        requestedBy: 'system-user',
        commissionRate: 0.075,
        isSystemOverride: true,
      });
    });

    it('defaults requestedBy and commissionRate when missing', () => {
      const payload = definition.parseInput(
        { productId: 'abc' },
        { auth: { uid: 'uid-1' } }
      );

      expect(payload).toMatchObject({
        buyerAuthUid: 'uid-1',
        requestedBy: 'uid-1',
        commissionRate: expect.any(Number),
        isSystemOverride: false,
      });
    });

    it('throws when auth or productId is missing', () => {
      expect(() => definition.parseInput({ productId: 'x' }, {})).toThrow(
        expect.objectContaining({ code: 'unauthenticated' })
      );
      expect(() => definition.parseInput({}, { auth: { uid: 'uid-1' } })).toThrow(
        expect.objectContaining({ code: 'invalid-argument' })
      );
    });

    it('binds SQL parameters correctly', () => {
      const inputs = [];
      const request = {
        input: jest.fn((name, type, value) => {
          inputs.push({ name, type, value });
          return request;
        }),
        output: jest.fn().mockReturnThis(),
      };

      definition.bind(request, {
        buyerAuthUid: 'buyer-1',
        productId: 'prod-9',
        requestedBy: 'system',
        commissionRate: 0.0555,
        isSystemOverride: true,
      });

      expect(inputs).toEqual([
        { name: 'BuyerAuthUid', type: 'NVarChar', value: 'buyer-1' },
        { name: 'ProductId', type: 'NVarChar', value: 'prod-9' },
        { name: 'RequestedBy', type: 'NVarChar', value: 'system' },
        { name: 'IsSystemOverride', type: mssql.Bit, value: 1 },
        { name: 'CommissionRate', type: 'Decimal', value: 0.0555 },
      ]);

      expect(mssql.Decimal).toHaveBeenCalledWith(5, 4);
    });
  });

  describe('storeReleaseEscrow definition', () => {
    const definition = getProcedure('storeReleaseEscrow');

    it('requires authentication and order id', () => {
      expect(() => definition.parseInput({}, {})).toThrow(expect.objectContaining({ code: 'unauthenticated' }));
      expect(() =>
        definition.parseInput({}, { auth: { uid: 'uid-1' } })
      ).toThrow(expect.objectContaining({ code: 'invalid-argument' }));
    });

    it('parses payload and trims values', () => {
      const payload = definition.parseInput(
        { orderId: ' ORDER-42 ', override: '1' },
        { auth: { uid: ' actor-5 ' } }
      );

      expect(payload).toEqual({
        orderId: 'ORDER-42',
        actorAuthUid: 'actor-5',
        isSystemOverride: true,
      });
    });

    it('binds SQL parameters correctly', () => {
      const inputs = [];
      const request = {
        input: jest.fn((name, type, value) => {
          inputs.push({ name, type, value });
          return request;
        }),
      };

      definition.bind(request, {
        orderId: 'ORDER-99',
        actorAuthUid: 'actor-1',
        isSystemOverride: false,
      });

      expect(inputs).toEqual([
        { name: 'OrderPublicId', type: 'NVarChar', value: 'ORDER-99' },
        { name: 'ActorAuthUid', type: 'NVarChar', value: 'actor-1' },
        { name: 'IsSystemOverride', type: mssql.Bit, value: 0 },
      ]);
    });
  });

  describe('storeRefundEscrow definition', () => {
    const definition = getProcedure('storeRefundEscrow');

    it('parses payload with optional refund reason', () => {
      const payload = definition.parseInput(
        { orderPublicId: ' order-11 ', refundReason: '  buyer request ', isSystemOverride: 'false' },
        { auth: { uid: ' admin-2 ' } }
      );

      expect(payload).toEqual({
        orderId: 'order-11',
        actorAuthUid: 'admin-2',
        isSystemOverride: false,
        refundReason: 'buyer request',
      });
    });

    it('normalizes empty refund reason to null', () => {
      const payload = definition.parseInput(
        { orderId: 'XYZ', refundReason: '   ' },
        { auth: { uid: 'actor' } }
      );

      expect(payload.refundReason).toBeNull();
    });

    it('binds SQL parameters including refund reason', () => {
      const inputs = [];
      const request = {
        input: jest.fn((name, type, value) => {
          inputs.push({ name, type, value });
          return request;
        }),
      };

      definition.bind(request, {
        orderId: 'order-22',
        actorAuthUid: 'actor-7',
        isSystemOverride: true,
        refundReason: null,
      });

      expect(inputs).toEqual([
        { name: 'OrderPublicId', type: 'NVarChar', value: 'order-22' },
        { name: 'ActorAuthUid', type: 'NVarChar', value: 'actor-7' },
        { name: 'IsSystemOverride', type: mssql.Bit, value: 1 },
        { name: 'RefundReason', type: 'NVarChar', value: null },
      ]);
    });
  });

  describe('storeAdjustWallet definition', () => {
    const definition = getProcedure('storeAdjustWallet');

    it('requires authentication and target uid', () => {
      expect(() => definition.parseInput({}, {})).toThrow(expect.objectContaining({ code: 'unauthenticated' }));
      expect(() =>
        definition.parseInput({ amount: 10 }, { auth: { uid: 'actor-1' } })
      ).toThrow(expect.objectContaining({ message: 'target_uid_required' }));
    });

    it('rejects invalid or zero amounts', () => {
      expect(() =>
        definition.parseInput({ userId: 'user-1', amount: 'abc' }, { auth: { uid: 'actor-1' } })
      ).toThrow(expect.objectContaining({ message: 'amount_delta_invalid' }));
      expect(() =>
        definition.parseInput({ userId: 'user-1', amount: 0 }, { auth: { uid: 'actor-1' } })
      ).toThrow(expect.objectContaining({ message: 'amount_delta_nonzero_required' }));
    });

    it('parses payload with metadata serialization', () => {
      const payload = definition.parseInput(
        {
          targetAuthUid: ' user-789 ',
          amountDelta: '-42.4',
          reason: '  manual adjustment ',
          metadata: { ticket: 'ops-1' },
          override: 'true',
        },
        { auth: { uid: ' admin-1 ' } }
      );

      expect(payload).toEqual({
        actorAuthUid: 'admin-1',
        targetAuthUid: 'user-789',
        amountDelta: -42,
        reason: 'manual adjustment',
        isSystemOverride: true,
        metadataJson: JSON.stringify({ ticket: 'ops-1' }),
      });
    });

    it('binds SQL parameters including metadata', () => {
      const inputs = [];
      const request = {
        input: jest.fn((name, type, value) => {
          inputs.push({ name, type, value });
          return request;
        }),
      };

      definition.bind(request, {
        targetAuthUid: 'user-1',
        actorAuthUid: 'admin-2',
        amountDelta: 100,
        reason: null,
        metadataJson: null,
        isSystemOverride: false,
      });

      expect(inputs).toEqual([
        { name: 'TargetAuthUid', type: 'NVarChar', value: 'user-1' },
        { name: 'ActorAuthUid', type: 'NVarChar', value: 'admin-2' },
        { name: 'AmountDelta', type: mssql.Int, value: 100 },
        { name: 'Reason', type: 'NVarChar', value: null },
        { name: 'MetadataJson', type: 'NVarChar', value: null },
        { name: 'IsSystemOverride', type: mssql.Bit, value: 0 },
      ]);
    });

    it('transforms SQL result into response payload', () => {
      const result = {
        recordset: [
          {
            NewBalance: 580,
            LedgerEntryId: 1234,
          },
        ],
        returnValue: 0,
      };

      const transformed = definition.transform(result, {
        targetAuthUid: 'user-1',
        amountDelta: 50,
      });

      expect(transformed).toEqual({
        targetAuthUid: 'user-1',
        amountDelta: 50,
        newBalance: 580,
        ledgerEntryId: '1234',
        status: 'adjusted',
        returnValue: 0,
      });
    });
  });

  describe('storeListProducts definition', () => {
    const definition = getProcedure('storeListProducts');

    it('parses filters with defaults', () => {
      const payload = definition.parseInput({
        limit: '150',
        category: '  electronics ',
        status: 'active',
        sellerType: 'p2p',
      });

      expect(payload).toEqual({
        limit: 150,
        category: 'electronics',
        status: 'ACTIVE',
        sellerType: 'P2P',
      });
    });

    it('binds SQL parameters for filters', () => {
      const inputs = [];
      const request = {
        input: jest.fn((name, type, value) => {
          inputs.push({ name, type, value });
          return request;
        }),
      };

      definition.bind(request, {
        limit: 75,
        category: null,
        status: null,
        sellerType: null,
      });

      expect(inputs).toEqual([
        { name: 'Limit', type: mssql.Int, value: 75 },
        { name: 'Category', type: 'NVarChar', value: null },
        { name: 'Status', type: 'NVarChar', value: null },
        { name: 'SellerType', type: 'NVarChar', value: null },
      ]);
    });

    it('transforms recordset into product list', () => {
      const now = new Date('2024-02-01T00:00:00Z');
      const result = {
        recordset: [
          {
            ProductId: 'prod-1',
            Title: 'Cool Item',
            Description: 'So cool',
            PriceGold: 900,
            ImagesJson: JSON.stringify(['a.png', 'b.png']),
            Category: 'collectibles',
            Condition: 'new',
            Status: 'ACTIVE',
            SellerAuthUid: 'seller-1',
            VendorId: null,
            SellerType: 'P2P',
            QrUid: 'qr-123',
            QrBound: true,
            ReservedBy: null,
            ReservedAt: null,
            CreatedAt: now,
            UpdatedAt: now,
          },
        ],
      };

      const transformed = definition.transform(result);

      expect(transformed).toEqual({
        products: [
          expect.objectContaining({
            id: 'prod-1',
            title: 'Cool Item',
            priceGold: 900,
            images: ['a.png', 'b.png'],
            status: 'active',
            sellerType: 'p2p',
          }),
        ],
        total: 1,
      });
    });
  });

  describe('storeGetProduct definition', () => {
    const definition = getProcedure('storeGetProduct');

    it('requires product id', () => {
      expect(() => definition.parseInput({}, {})).toThrow(expect.objectContaining({ code: 'invalid-argument' }));
    });

    it('binds SQL parameter and transforms record', () => {
      const inputs = [];
      const request = {
        input: jest.fn((name, type, value) => {
          inputs.push({ name, type, value });
          return request;
        }),
      };

      definition.bind(request, { productId: 'prod-2' });
      expect(inputs).toEqual([{ name: 'ProductId', type: 'NVarChar', value: 'prod-2' }]);

      const result = {
        recordset: [
          {
            ProductId: 'prod-2',
            Title: 'Item 2',
            Status: 'inactive',
          },
        ],
      };

      const output = definition.transform(result);
      expect(output.product).toEqual(expect.objectContaining({ id: 'prod-2', title: 'Item 2' }));
    });

    it('throws not-found when record missing', () => {
      expect(() => definition.transform({ recordset: [] })).toThrow(expect.objectContaining({ code: 'not-found' }));
    });
  });

  describe('storeGetWallet definition', () => {
    const definition = getProcedure('storeGetWallet');

    it('requires auth uid from payload or context', () => {
      expect(() => definition.parseInput({}, {})).toThrow(expect.objectContaining({ code: 'unauthenticated' }));

      const payload = definition.parseInput({ targetAuthUid: ' user-1 ' }, {});
      expect(payload).toEqual({ targetAuthUid: 'user-1', createIfMissing: false });

      const payloadFromContext = definition.parseInput({}, { auth: { uid: 'user-2' } });
      expect(payloadFromContext).toEqual({ targetAuthUid: 'user-2', createIfMissing: false });
    });

    it('binds SQL parameters and transforms results', () => {
      const inputs = [];
      const request = {
        input: jest.fn((name, type, value) => {
          inputs.push({ name, type, value });
          return request;
        }),
      };

      definition.bind(request, { targetAuthUid: 'user-3', createIfMissing: true });

      expect(inputs).toEqual([
        { name: 'TargetAuthUid', type: 'NVarChar', value: 'user-3' },
        { name: 'CreateIfMissing', type: mssql.Bit, value: 1 },
      ]);

      const now = new Date('2024-03-01T00:00:00Z');
      const result = {
        recordsets: [
          [
            {
              WalletId: 1,
              AuthUid: 'user-3',
              GoldBalance: 500,
              PendingGold: 50,
              CreatedAt: now,
              UpdatedAt: now,
            },
          ],
          [
            {
              LedgerId: 10,
              WalletId: 1,
              AmountDelta: 100,
              Reason: 'deposit',
              CreatedAt: now,
            },
          ],
        ],
      };

      const output = definition.transform(result);
      expect(output.wallet).toEqual(
        expect.objectContaining({ authUid: 'user-3', goldBalance: 500, pendingGold: 50 })
      );
      expect(output.ledger).toHaveLength(1);
    });

    it('returns null wallet when no record', () => {
      const output = definition.transform({ recordsets: [[]] });
      expect(output).toEqual({ wallet: null, ledger: [] });
    });
  });

  describe('storeListOrdersForBuyer definition', () => {
    const definition = getProcedure('storeListOrdersForBuyer');

    it('requires authenticated buyer and enforces matching uid', () => {
      expect(() => definition.parseInput({}, {})).toThrow(expect.objectContaining({ code: 'permission-denied' }));
      expect(() =>
        definition.parseInput({ buyerAuthUid: 'user-1' }, { auth: { uid: 'user-2' } })
      ).toThrow(expect.objectContaining({ code: 'permission-denied' }));

      const payload = definition.parseInput({ limit: '5' }, { auth: { uid: 'user-3' } });
      expect(payload).toEqual({ buyerAuthUid: 'user-3', limit: 5 });
    });

    it('binds SQL parameters and transforms orders', () => {
      const inputs = [];
      const request = {
        input: jest.fn((name, type, value) => {
          inputs.push({ name, type, value });
          return request;
        }),
      };

      definition.bind(request, { buyerAuthUid: 'user-4', limit: 25 });

      expect(inputs).toEqual([
        { name: 'BuyerAuthUid', type: 'NVarChar', value: 'user-4' },
        { name: 'Limit', type: mssql.Int, value: 25 },
      ]);

      const now = new Date('2024-04-01T00:00:00Z');
      const result = {
        recordset: [
          {
            OrderPublicId: 'order-1',
            ProductId: 'prod-9',
            BuyerAuthUid: 'user-4',
            SellerAuthUid: 'seller-1',
            Status: 'PENDING',
            PaymentStatus: 'AWAITING_ESCROW',
            CreatedAt: now,
            UpdatedAt: now,
          },
        ],
      };

      const output = definition.transform(result);
      expect(output.orders).toEqual([
        expect.objectContaining({ orderId: 'order-1', status: 'PENDING' }),
      ]);
      expect(output.total).toBe(1);
    });
  });

  describe('dmSend definition', () => {
    const definition = getProcedure('dmSend');

    const baseEnvelope = {
      id: 'evt-1',
      type: 'dm.message.create',
      source: 'flutter://direct-message/send',
      time: '2025-01-01T00:00:00.000Z',
      data: {
        operation: 'create',
        conversationId: 'conv-123',
        messageId: 'msg-456',
        clientMessageId: 'client-456',
        senderId: 'user-99',
        participantMeta: {
          'user-99': { displayName: 'Sender' },
        },
        document: {
          senderId: 'user-99',
          text: 'hello world',
        },
        previousDocument: null,
      },
    };

    it('parses event envelope into SQL payload', () => {
      const payload = definition.parseInput(baseEnvelope, { auth: { uid: 'user-99' } });

      expect(payload.eventType).toBe('dm.message.create');
      expect(payload.operation).toBe('create');
      expect(payload.source).toBe('flutter://direct-message/send');
      expect(payload.metadata).toMatchObject({
        conversationId: 'conv-123',
        messageId: 'msg-456',
        senderId: 'user-99',
      });
      expect(payload.document).toEqual(baseEnvelope.data.document);
    });

    it('rejects sender mismatch between envelope and auth context', () => {
      expect(() =>
        definition.parseInput(baseEnvelope, { auth: { uid: 'different-user' } })
      ).toThrow(expect.objectContaining({ code: 'permission-denied' }));
    });

    it('binds SQL parameters for stored procedure execution', () => {
      const payload = definition.parseInput(baseEnvelope, { auth: { uid: 'user-99' } });
      const inputs = [];
      const request = {
        input: jest.fn((name, type, value) => {
          inputs.push({ name, type, value });
          return request;
        }),
      };

      definition.bind(request, payload);

      expect(inputs).toEqual(
        expect.arrayContaining([
          { name: 'EventType', type: 'NVarChar', value: 'dm.message.create' },
          { name: 'Operation', type: 'NVarChar', value: 'create' },
          { name: 'Source', type: 'NVarChar', value: expect.any(String) },
          { name: 'EventId', type: 'NVarChar', value: expect.any(String) },
          {
            name: 'DocumentJson',
            type: 'NVarChar',
            value: JSON.stringify(baseEnvelope.data.document),
          },
          {
            name: 'MetadataJson',
            type: 'NVarChar',
            value: JSON.stringify(payload.metadata),
          },
        ])
      );

      const timestampParam = inputs.find((item) => item.name === 'EventTimestamp');
      expect(timestampParam).toBeDefined();
      expect(timestampParam.type).toBe('DateTimeOffset');
      expect(timestampParam.value).toBeInstanceOf(Date);
      expect(mssql.NVarChar.mock.calls.some((args) => args[0] === 'MAX')).toBe(true);
    });

    it('transforms SQL response with rowsAffected into success payload', () => {
      const payload = definition.parseInput(baseEnvelope, { auth: { uid: 'user-99' } });
      const result = definition.transform(
        { rowsAffected: [1, 2, 0] },
        payload
      );

      expect(result).toEqual({
        ok: true,
        rowsAffected: 3,
        eventId: expect.any(String),
      });
    });
  });

  describe('followEdgeUpsert definition', () => {
    const definition = getProcedure('followEdgeUpsert');

    const baseEnvelope = {
      id: 'follow-evt-1',
      type: 'follow.edge.create',
      source: 'flutter://follow-service',
      time: '2025-02-02T12:00:00.000Z',
      data: {
        operation: 'create',
        userId: 'user-42',
        targetId: 'user-77',
        timestamp: '2025-02-02T12:00:00.000Z',
        document: {
          status: 'ACTIVE',
          source: 'flutter://follow-service',
          createdAt: '2025-02-02T12:00:00.000Z',
          updatedAt: '2025-02-02T12:00:00.000Z',
        },
        previousDocument: null,
      },
    };

    it('parses follow envelope into SQL payload', () => {
      const payload = definition.parseInput(baseEnvelope, { auth: { uid: 'user-42' } });

      expect(payload.eventType).toBe('follow.edge.create');
      expect(payload.operation).toBe('create');
      expect(payload.source).toBe('flutter://follow-service');
      expect(payload.metadata).toMatchObject({
        userId: 'user-42',
        targetId: 'user-77',
        operation: 'create',
      });
      expect(payload.document).toEqual(baseEnvelope.data.document);
    });

    it('rejects when event type is not follow edge', () => {
      expect(() =>
        definition.parseInput({ ...baseEnvelope, type: 'dm.message.create' }, { auth: { uid: 'user-42' } })
      ).toThrow(expect.objectContaining({ code: 'invalid-argument' }));
    });

    it('rejects when auth user does not match envelope', () => {
      expect(() =>
        definition.parseInput(baseEnvelope, { auth: { uid: 'other-user' } })
      ).toThrow(expect.objectContaining({ code: 'permission-denied' }));
    });

    it('binds SQL parameters for follow edge procedure', () => {
      const payload = definition.parseInput(baseEnvelope, { auth: { uid: 'user-42' } });
      const inputs = [];
      const request = {
        input: jest.fn((name, type, value) => {
          inputs.push({ name, type, value });
          return request;
        }),
      };

      definition.bind(request, payload);

      expect(inputs).toEqual(
        expect.arrayContaining([
          { name: 'EventType', type: 'NVarChar', value: 'follow.edge.create' },
          { name: 'Operation', type: 'NVarChar', value: 'create' },
          { name: 'Source', type: 'NVarChar', value: expect.any(String) },
          { name: 'EventId', type: 'NVarChar', value: expect.any(String) },
          {
            name: 'DocumentJson',
            type: 'NVarChar',
            value: JSON.stringify(baseEnvelope.data.document),
          },
          {
            name: 'MetadataJson',
            type: 'NVarChar',
            value: JSON.stringify(payload.metadata),
          },
        ])
      );

      const timestampParam = inputs.find((item) => item.name === 'EventTimestamp');
      expect(timestampParam).toBeDefined();
      expect(timestampParam.type).toBe('DateTimeOffset');
      expect(timestampParam.value).toBeInstanceOf(Date);
      expect(mssql.NVarChar.mock.calls.some((args) => args[0] === 'MAX')).toBe(true);
    });

    it('transforms SQL response to include rowsAffected', () => {
      const payload = definition.parseInput(baseEnvelope, { auth: { uid: 'user-42' } });
      const result = definition.transform({ rowsAffected: [2] }, payload);

      expect(result).toEqual({
        ok: true,
        rowsAffected: 2,
        eventId: expect.any(String),
      });
    });
  });
});
