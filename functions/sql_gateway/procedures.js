const mssql = require('mssql');
const functions = require('firebase-functions');

const DEFAULT_REGION = process.env.SQL_GATEWAY_REGION || process.env.ENSURE_SQL_USER_REGION || 'europe-west1';

const DEFAULT_COMMISSION_RATE = (() => {
  const raw = Number.parseFloat(process.env.STORE_DEFAULT_COMMISSION_RATE || '0.05');
  if (!Number.isFinite(raw)) {
    return 0.05;
  }
  if (raw < 0) {
    return 0.0;
  }
  if (raw > 1) {
    return 1.0;
  }
  return Math.round(raw * 10000) / 10000;
})();

const procedures = new Map();

function defineProcedure(key, definition) {
  procedures.set(key, Object.freeze(definition));
}

function getProcedure(key) {
  return procedures.get(key);
}

function listProcedureKeys() {
  return Array.from(procedures.keys());
}

function toTrimmedString(value) {
  if (value == null) {
    return '';
  }
  return value.toString().trim();
}

function toBooleanFlag(value) {
  if (value === true || value === false) {
    return value;
  }
  if (typeof value === 'number') {
    return value !== 0;
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (['true', '1', 'yes', 'on'].includes(normalized)) {
      return true;
    }
    if (['false', '0', 'no', 'off'].includes(normalized)) {
      return false;
    }
  }
  return false;
}

function booleanFrom(value) {
  return toBooleanFlag(value);
}

function toCommissionRate(value) {
  if (value === undefined || value === null || value === '') {
    return DEFAULT_COMMISSION_RATE;
  }
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return DEFAULT_COMMISSION_RATE;
  }
  if (parsed < 0) {
    return 0;
  }
  if (parsed > 1) {
    return 1;
  }
  return Math.round(parsed * 10000) / 10000;
}

function parseGoldAmount(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return null;
  }
  const rounded = Math.round(parsed);
  if (rounded === 0) {
    return 0;
  }
  return rounded;
}

function toSafeIsoString(value) {
  if (!value) {
    return null;
  }
  try {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      return null;
    }
    return date.toISOString();
  } catch (error) {
    functions.logger.warn('sqlGateway.invalid_date_value', {
      fieldValue: value,
    });
    return null;
  }
}

function parseJsonArrayOfStrings(value) {
  if (!value) {
    return [];
  }
  if (Array.isArray(value)) {
    return value.map((item) => item?.toString?.() ?? '').filter((item) => item.length > 0);
  }
  try {
    const parsed = JSON.parse(value);
    if (!Array.isArray(parsed)) {
      return [];
    }
    return parsed.map((item) => item?.toString?.() ?? '').filter((item) => item.length > 0);
  } catch (error) {
    functions.logger.warn('sqlGateway.parse_images_failed', {
      rawValue: value,
      message: error?.message,
    });
    return [];
  }
}

function parseTimelineJson(value) {
  if (!value) {
    return [];
  }
  try {
    const parsed = typeof value === 'string' ? JSON.parse(value) : value;
    if (!Array.isArray(parsed)) {
      return [];
    }
    return parsed
      .map((item) => {
        if (item && typeof item === 'object') {
          return {
            status: toTrimmedString(item.status) || null,
            message: item.message?.toString?.() ?? '',
            createdAt: toSafeIsoString(item.createdAt ?? item.created_at ?? null),
          };
        }
        return null;
      })
      .filter(Boolean);
  } catch (error) {
    functions.logger.warn('sqlGateway.parse_timeline_failed', {
      rawValue: value,
      message: error?.message,
    });
    return [];
  }
}

function parseJsonValue(value, fallback = null, logKey = 'json_value') {
  if (value === undefined || value === null) {
    return fallback;
  }

  if (typeof value === 'object') {
    return value;
  }

  const raw = value.toString().trim();
  if (raw.length === 0 || raw === 'null') {
    return fallback;
  }

  try {
    return JSON.parse(raw);
  } catch (error) {
    functions.logger.warn('sqlGateway.json_parse_failed', {
      key: logKey,
      message: error?.message,
    });
    return fallback;
  }
}

function parseJsonObject(value, fallback = null, logKey = 'json_object') {
  const parsed = parseJsonValue(value, fallback, logKey);
  if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
    return parsed;
  }
  if (parsed === null || parsed === undefined) {
    return fallback;
  }
  return fallback;
}

function parseJsonArrayValue(value, fallback = [], logKey = 'json_array') {
  const parsed = parseJsonValue(value, fallback, logKey);
  if (Array.isArray(parsed)) {
    return parsed;
  }
  if (parsed === null || parsed === undefined) {
    return fallback;
  }
  return fallback;
}

function parseSqlConversationRecord(record = {}) {
  const conversationId = toTrimmedString(record.ConversationFirestoreId) || null;
  const lastMessageTimestamp = toSafeIsoString(record.LastMessageTimestamp);
  const lastEventTimestamp = toSafeIsoString(record.LastEventTimestamp);
  const createdAtIso = toSafeIsoString(record.CreatedAt);
  const updatedAtIso = toSafeIsoString(record.UpdatedAt);
  const readPointerTimestamp = toSafeIsoString(record.UserReadPointerTimestamp);

  const lastMessageId = toTrimmedString(record.LastMessageFirestoreId);
  const conversationKey = toTrimmedString(record.ConversationKey) || conversationId;

  const conversation = {
    conversationId,
    conversationKey,
    type: toTrimmedString(record.ConversationType)?.toLowerCase() || 'direct',
    isGroup: Boolean(record.IsGroup),
    memberCount:
      record.MemberCount === null || record.MemberCount === undefined
        ? null
        : Number(record.MemberCount),
    metadata: parseJsonObject(record.MetadataJson, null, 'dmListConversations.metadata'),
    participantMeta: parseJsonObject(
      record.ParticipantMetaJson,
      null,
      'dmListConversations.participantMeta',
    ),
    readPointers: parseJsonObject(record.ReadPointersJson, null, 'dmListConversations.readPointers'),
    participants: parseJsonArrayValue(
      record.ParticipantsJson,
      [],
      'dmListConversations.participants',
    ),
    lastMessage: lastMessageId
      ? {
          messageId: lastMessageId,
          senderId: toTrimmedString(record.LastMessageSenderId) || null,
          preview: record.LastMessagePreview ?? null,
          timestamp: lastMessageTimestamp,
        }
      : null,
    createdAt: createdAtIso,
    updatedAt: updatedAtIso,
    lastEvent:
      record.LastEventId || record.LastEventTimestamp
        ? {
            id: toTrimmedString(record.LastEventId) || null,
            timestamp: lastEventTimestamp,
          }
        : null,
    myState: {
      readPointerMessageId: toTrimmedString(record.UserReadPointerMessageId) || null,
      readPointerTimestamp: readPointerTimestamp,
      metadata: parseJsonObject(record.UserMetadataJson, null, 'dmListConversations.userMetadata'),
    },
  };

  return conversation;
}

function parseSqlDmMessageRecord(record = {}) {
  return {
    messageId: toTrimmedString(record.MessageFirestoreId) || null,
    clientMessageId: toTrimmedString(record.ClientMessageId) || null,
    authorUserId: toTrimmedString(record.AuthorUserId) || null,
    bodyText: record.BodyText ?? null,
    attachments: parseJsonValue(record.AttachmentJson, null, 'dmListMessages.attachments'),
    externalMedia: parseJsonValue(
      record.ExternalMediaJson,
      null,
      'dmListMessages.externalMedia',
    ),
    deletedFor: parseJsonValue(record.DeletedForJson, null, 'dmListMessages.deletedFor'),
    tombstone: parseJsonValue(record.TombstoneJson, null, 'dmListMessages.tombstone'),
    createdAt: toSafeIsoString(record.CreatedAt),
    updatedAt: toSafeIsoString(record.UpdatedAt),
    editedAt: toSafeIsoString(record.EditedAt),
    editedBy: toTrimmedString(record.EditedBy) || null,
    deletedAt: toSafeIsoString(record.DeletedAt),
    deletedBy: toTrimmedString(record.DeletedBy) || null,
    source: toTrimmedString(record.Source) || null,
    lastEvent:
      record.LastEventId || record.LastEventTimestamp
        ? {
            id: toTrimmedString(record.LastEventId) || null,
            timestamp: toSafeIsoString(record.LastEventTimestamp),
          }
        : null,
  };
}

function parseSqlFollowEdgeRecord(record = {}, logPrefix = 'followGetRelationship.edge') {
  const follower = toTrimmedString(record.FollowerUserId) || null;
  const target = toTrimmedString(record.TargetUserId) || null;
  const computedId =
    toTrimmedString(record.EdgeId) ||
    (follower && target ? `${follower}_${target}` : null);

  return {
    id: computedId,
    srcUid: follower,
    dstUid: target,
    status: toTrimmedString(record.State)?.toUpperCase() || null,
    source: toTrimmedString(record.Source) || null,
    createdAt: toSafeIsoString(record.CreatedAt),
    updatedAt: toSafeIsoString(record.UpdatedAt),
    lastEventId: toTrimmedString(record.LastEventId) || null,
    lastEventTimestamp: toSafeIsoString(record.LastEventTimestamp),
    metadata: parseJsonObject(record.MetadataJson, null, `${logPrefix}.metadata`),
  };
}

function parseSqlBlockEdgeRecord(record = {}, logPrefix = 'followGetRelationship.block') {
  const src =
    toTrimmedString(record.UserId) ||
    toTrimmedString(record.BlockerUserId) ||
    toTrimmedString(record.SrcUid) ||
    toTrimmedString(record.SourceUserId) ||
    null;
  const dst =
    toTrimmedString(record.TargetUserId) ||
    toTrimmedString(record.BlockedUserId) ||
    toTrimmedString(record.DstUid) ||
    toTrimmedString(record.TargetUid) ||
    null;

  const computedId =
    toTrimmedString(record.BlockId) ||
    toTrimmedString(record.Id) ||
    (src && dst ? `${src}_${dst}` : null);

  return {
    id: computedId,
    srcUid: src,
    dstUid: dst,
    createdAt: toSafeIsoString(record.CreatedAt),
    revokedAt: toSafeIsoString(record.RevokedAt),
    source: toTrimmedString(record.Source) || null,
    metadata: parseJsonObject(record.MetadataJson, null, `${logPrefix}.metadata`),
  };
}

function parseProductRecord(record = {}) {
  return {
    id: record.ProductId ?? null,
    title: record.Title ?? null,
    desc: record.Description ?? null,
    priceGold: Number(record.PriceGold ?? 0),
    images: parseJsonArrayOfStrings(record.ImagesJson),
    category: record.Category ?? null,
    condition: record.Condition ?? null,
    status: toTrimmedString(record.Status)?.toLowerCase() ?? null,
    sellerAuthUid: record.SellerAuthUid ?? null,
    vendorId: record.VendorId ?? null,
    sellerType: toTrimmedString(record.SellerType)?.toLowerCase() ?? null,
    qrUid: record.QrUid ?? null,
    qrBound: Boolean(record.QrBound),
    reservedBy: record.ReservedBy ?? null,
    reservedAt: toSafeIsoString(record.ReservedAt),
    sharedEntryId: record.SharedEntryId ?? null,
    sharedByAuthUid: record.SharedByAuthUid ?? null,
    sharedAt: toSafeIsoString(record.SharedAt),
    createdAt: toSafeIsoString(record.CreatedAt),
    updatedAt: toSafeIsoString(record.UpdatedAt),
  };
}

function parseWalletRecord(record = {}) {
  return {
    authUid: record.AuthUid ?? null,
    walletId: record.WalletId ?? null,
    goldBalance: Number(record.GoldBalance ?? 0),
    pendingGold: Number(record.PendingGold ?? 0),
    lastLedgerEntryId: record.LastLedgerEntryId ?? null,
    createdAt: toSafeIsoString(record.CreatedAt),
    updatedAt: toSafeIsoString(record.UpdatedAt),
  };
}

function parseLedgerRecord(record = {}) {
  return {
    ledgerId: record.LedgerId ?? null,
    walletId: record.WalletId ?? null,
    targetAuthUid: record.TargetAuthUid ?? null,
    actorAuthUid: record.ActorAuthUid ?? null,
    amountDelta: Number(record.AmountDelta ?? 0),
    reason: record.Reason ?? null,
    metadataJson: record.MetadataJson ?? null,
    createdAt: toSafeIsoString(record.CreatedAt),
  };
}

function parseOrderRecord(record = {}) {
  return {
    orderId: record.OrderPublicId ?? null,
    productId: record.ProductId ?? null,
    buyerAuthUid: record.BuyerAuthUid ?? null,
    sellerAuthUid: record.SellerAuthUid ?? null,
    vendorId: record.VendorId ?? null,
    sellerType: toTrimmedString(record.SellerType)?.toLowerCase() ?? null,
    itemPriceGold: Number(record.ItemPriceGold ?? 0),
    commissionGold: Number(record.CommissionGold ?? 0),
    totalGold: Number(record.TotalGold ?? 0),
    status: toTrimmedString(record.Status)?.toUpperCase() ?? null,
    paymentStatus: toTrimmedString(record.PaymentStatus)?.toUpperCase() ?? null,
    createdAt: toSafeIsoString(record.CreatedAt),
    updatedAt: toSafeIsoString(record.UpdatedAt),
    deliveredAt: toSafeIsoString(record.DeliveredAt),
    releasedAt: toSafeIsoString(record.ReleasedAt),
    refundedAt: toSafeIsoString(record.RefundedAt),
    disputedAt: toSafeIsoString(record.DisputedAt),
    completedAt: toSafeIsoString(record.CompletedAt),
    canceledAt: toSafeIsoString(record.CanceledAt ?? record.CancelledAt),
    escrow: {
      state: toTrimmedString(record.EscrowState)?.toUpperCase() ?? null,
      lockedAmountGold: Number(record.LockedAmountGold ?? 0),
      releasedAmountGold: Number(record.ReleasedAmountGold ?? 0),
      refundedAmountGold: Number(record.RefundedAmountGold ?? 0),
      lockedAt: toSafeIsoString(record.LockedAt),
      releasedAt: toSafeIsoString(record.EscrowReleasedAt ?? record.ReleasedAt),
      refundedAt: toSafeIsoString(record.EscrowRefundedAt ?? record.RefundedAt),
    },
    timeline: parseTimelineJson(record.TimelineJson),
  };
}

defineProcedure('ensureUser', {
  region: DEFAULT_REGION,
  requireAppCheck: true,
  access: {
    resource: 'users',
    action: 'sync',
  },
  parseInput(data = {}, context = {}) {
    const authUid = context.auth?.uid;
    if (!authUid) {
      throw new functions.https.HttpsError('unauthenticated', 'authentication_required');
    }

    const username = (data.username ?? '').toString().trim();
    const displayName = (data.displayName ?? data.fullName ?? '').toString().trim();
    const email = (data.email ?? context.auth?.token?.email ?? '').toString().trim();

    if (!username) {
      throw new functions.https.HttpsError('invalid-argument', 'username_required');
    }

    if (!email) {
      throw new functions.https.HttpsError('invalid-argument', 'email_required');
    }

    return {
      authUid,
      username,
      displayName: displayName || username,
      email,
    };
  },
  bind(request, payload) {
    request.input('AuthUid', mssql.NVarChar(64), payload.authUid);
    request.input('Email', mssql.NVarChar(256), payload.email);
    request.input('Username', mssql.NVarChar(64), payload.username);
    request.input('DisplayName', mssql.NVarChar(128), payload.displayName);
    request.output('UserId', mssql.Int);
    request.output('Created', mssql.Bit);
  },
  async execute(request) {
    return request.execute('dbo.sp_EnsureUser');
  },
  transform(result) {
    const userId = result.output?.UserId;
    const createdValue = result.output?.Created;
    const created = createdValue === true || createdValue === 1 || createdValue === '1';

    if (!Number.isInteger(userId)) {
      throw new Error('SQL_GATEWAY_NO_RESULT');
    }

    return {
      userId,
      created,
    };
  },
});

defineProcedure('getUserProfile', {
  region: DEFAULT_REGION,
  requireAppCheck: true,
  access: {
    resource: 'users',
    action: 'read',
  },
  parseInput(data = {}, context = {}) {
    const explicitAuthUid = toTrimmedString(data.authUid);
    const callerAuthUid = toTrimmedString(context.auth?.uid);
    const authUid = explicitAuthUid || callerAuthUid;

    if (!authUid) {
      throw new functions.https.HttpsError('invalid-argument', 'auth_uid_required');
    }

    return { authUid };
  },
  bind(request, payload) {
    request.input('AuthUid', mssql.NVarChar(64), payload.authUid);
  },
  async execute(request) {
    return request.execute('dbo.sp_GetUserProfile');
  },
  transform(result, payload) {
    const record = Array.isArray(result?.recordset) ? result.recordset[0] : undefined;

    if (!record) {
      throw new functions.https.HttpsError('not-found', 'user_profile_not_found');
    }

    const toIsoString = (value) => {
      if (!value) {
        return null;
      }
      try {
        return new Date(value).toISOString();
      } catch (error) {
        functions.logger.warn('sqlGateway.invalid_date_field', {
          key: 'getUserProfile',
          fieldValue: value,
        });
        return null;
      }
    };

    return {
      userId: record.UserId ?? null,
      authUid: record.AuthUid ?? payload.authUid,
      email: record.Email ?? null,
      username: record.Username ?? null,
      displayName: record.DisplayName ?? null,
      createdAt: toIsoString(record.CreatedAt),
      updatedAt: toIsoString(record.UpdatedAt),
    };
  },
  logContextBuilder(result, payload) {
    const record = Array.isArray(result?.recordset) ? result.recordset[0] : undefined;
    return {
      authUid: payload.authUid,
      userId: record?.UserId ?? null,
    };
  },
  scopeContextBuilder(data, context, payload) {
    return {
      authUid: payload.authUid,
      callerUid: context.auth?.uid ?? null,
    };
  },
});

defineProcedure('storeCreateOrder', {
  region: DEFAULT_REGION,
  requireAppCheck: true,
  access: {
    resource: 'store.orders',
    action: 'create',
  },
  parseInput(data = {}, context = {}) {
    const buyerAuthUid = toTrimmedString(context.auth?.uid);
    if (!buyerAuthUid) {
      throw new functions.https.HttpsError('unauthenticated', 'authentication_required');
    }

    const productId = toTrimmedString(data.productId);
    if (!productId) {
      throw new functions.https.HttpsError('invalid-argument', 'product_id_required');
    }

    const commissionRate = toCommissionRate(data.commissionRate);
    const isSystemOverride = toBooleanFlag(data.isSystemOverride ?? data.override);
    const requestedBy = toTrimmedString(data.requestedBy) || buyerAuthUid;

    return {
      buyerAuthUid,
      productId,
      requestedBy,
      commissionRate,
      isSystemOverride,
    };
  },
  bind(request, payload) {
    request.input('BuyerAuthUid', mssql.NVarChar(64), payload.buyerAuthUid);
    request.input('ProductId', mssql.NVarChar(64), payload.productId);
    request.input('RequestedBy', mssql.NVarChar(64), payload.requestedBy);
    request.input('IsSystemOverride', mssql.Bit, payload.isSystemOverride ? 1 : 0);
    request.input('CommissionRate', mssql.Decimal(5, 4), payload.commissionRate);
    request.output('OrderPublicId', mssql.NVarChar(64));
  },
  async execute(request) {
    return request.execute('dbo.sp_Store_CreateOrderAndLockEscrow');
  },
  transform(result) {
    const orderPublicId = toTrimmedString(result?.output?.OrderPublicId);
    if (!orderPublicId) {
      throw new functions.https.HttpsError('internal', 'order_creation_failed');
    }
    return {
      orderId: orderPublicId,
    };
  },
  logContextBuilder(result) {
    return {
      orderId: toTrimmedString(result?.output?.OrderPublicId) || null,
    };
  },
  scopeContextBuilder(data, context, payload) {
    return {
      productId: payload.productId,
      buyerAuthUid: payload.buyerAuthUid,
      callerUid: context.auth?.uid ?? null,
    };
  },
});

defineProcedure('storeReleaseEscrow', {
  region: DEFAULT_REGION,
  requireAppCheck: true,
  access: {
    resource: 'store.orders',
    action: 'release',
  },
  parseInput(data = {}, context = {}) {
    const actorAuthUid = toTrimmedString(context.auth?.uid);
    if (!actorAuthUid) {
      throw new functions.https.HttpsError('unauthenticated', 'authentication_required');
    }

    const orderId = toTrimmedString(data.orderId || data.orderPublicId);
    if (!orderId) {
      throw new functions.https.HttpsError('invalid-argument', 'order_id_required');
    }

    const isSystemOverride = toBooleanFlag(data.isSystemOverride ?? data.override);

    return {
      orderId,
      actorAuthUid,
      isSystemOverride,
    };
  },
  bind(request, payload) {
    request.input('OrderPublicId', mssql.NVarChar(64), payload.orderId);
    request.input('ActorAuthUid', mssql.NVarChar(64), payload.actorAuthUid);
    request.input('IsSystemOverride', mssql.Bit, payload.isSystemOverride ? 1 : 0);
  },
  async execute(request) {
    return request.execute('dbo.sp_Store_ReleaseEscrow');
  },
  transform(result, payload) {
    return {
      orderId: payload.orderId,
      status: 'released',
      returnValue: result?.returnValue ?? null,
    };
  },
  logContextBuilder(result, payload) {
    return {
      orderId: payload.orderId,
      returnValue: result?.returnValue ?? null,
    };
  },
  scopeContextBuilder(data, context, payload) {
    return {
      orderId: payload.orderId,
      callerUid: context.auth?.uid ?? null,
    };
  },
});

defineProcedure('storeRefundEscrow', {
  region: DEFAULT_REGION,
  requireAppCheck: true,
  access: {
    resource: 'store.orders',
    action: 'refund',
  },
  parseInput(data = {}, context = {}) {
    const actorAuthUid = toTrimmedString(context.auth?.uid);
    if (!actorAuthUid) {
      throw new functions.https.HttpsError('unauthenticated', 'authentication_required');
    }

    const orderId = toTrimmedString(data.orderId || data.orderPublicId);
    if (!orderId) {
      throw new functions.https.HttpsError('invalid-argument', 'order_id_required');
    }

    const isSystemOverride = toBooleanFlag(data.isSystemOverride ?? data.override);
    const refundReason = toTrimmedString(data.refundReason);

    return {
      orderId,
      actorAuthUid,
      isSystemOverride,
      refundReason: refundReason || null,
    };
  },
  bind(request, payload) {
    request.input('OrderPublicId', mssql.NVarChar(64), payload.orderId);
    request.input('ActorAuthUid', mssql.NVarChar(64), payload.actorAuthUid);
    request.input('IsSystemOverride', mssql.Bit, payload.isSystemOverride ? 1 : 0);
    request.input('RefundReason', mssql.NVarChar(256), payload.refundReason);
  },
  async execute(request) {
    return request.execute('dbo.sp_Store_RefundEscrow');
  },
  transform(result, payload) {
    return {
      orderId: payload.orderId,
      status: 'refunded',
      returnValue: result?.returnValue ?? null,
    };
  },
  logContextBuilder(result, payload) {
    return {
      orderId: payload.orderId,
      returnValue: result?.returnValue ?? null,
    };
  },
  scopeContextBuilder(data, context, payload) {
    return {
      orderId: payload.orderId,
      callerUid: context.auth?.uid ?? null,
    };
  },
});

defineProcedure('storeAdjustWallet', {
  region: DEFAULT_REGION,
  requireAppCheck: true,
  access: {
    resource: 'store.wallets',
    action: 'adjust',
  },
  parseInput(data = {}, context = {}) {
    const actorAuthUid = toTrimmedString(context.auth?.uid);
    if (!actorAuthUid) {
      throw new functions.https.HttpsError('unauthenticated', 'authentication_required');
    }

    const targetAuthUid = toTrimmedString(
      data.targetAuthUid ?? data.targetUid ?? data.targetUserId ?? data.userId
    );
    if (!targetAuthUid) {
      throw new functions.https.HttpsError('invalid-argument', 'target_uid_required');
    }

    const amountDelta = parseGoldAmount(data.amount ?? data.amountDelta ?? data.delta);
    if (amountDelta === null) {
      throw new functions.https.HttpsError('invalid-argument', 'amount_delta_invalid');
    }
    if (amountDelta === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'amount_delta_nonzero_required');
    }

    const reason = toTrimmedString(data.reason);
    const isSystemOverride = toBooleanFlag(data.isSystemOverride ?? data.override);

    let metadataJson = null;
    if (data.metadata !== undefined && data.metadata !== null) {
      if (typeof data.metadata === 'string') {
        const trimmed = data.metadata.trim();
        metadataJson = trimmed || null;
      } else {
        try {
          metadataJson = JSON.stringify(data.metadata);
        } catch (error) {
          throw new functions.https.HttpsError('invalid-argument', 'metadata_serialization_failed');
        }
      }
    }

    return {
      actorAuthUid,
      targetAuthUid,
      amountDelta,
      reason: reason || null,
      isSystemOverride,
      metadataJson,
    };
  },
  bind(request, payload) {
    request.input('TargetAuthUid', mssql.NVarChar(64), payload.targetAuthUid);
    request.input('ActorAuthUid', mssql.NVarChar(64), payload.actorAuthUid);
    request.input('AmountDelta', mssql.Int, payload.amountDelta);
    request.input('Reason', mssql.NVarChar(256), payload.reason);
    request.input('MetadataJson', mssql.NVarChar(1024), payload.metadataJson);
    request.input('IsSystemOverride', mssql.Bit, payload.isSystemOverride ? 1 : 0);
  },
  async execute(request) {
    return request.execute('dbo.sp_Store_AdjustWalletBalance');
  },
  transform(result, payload) {
    const record = Array.isArray(result?.recordset) ? result.recordset[0] : undefined;
    const newBalance = Number(record?.NewBalance ?? result?.output?.NewBalance);
    const ledgerEntryIdRaw = record?.LedgerEntryId ?? result?.output?.LedgerEntryId ?? null;
    const ledgerEntryId = ledgerEntryIdRaw == null ? null : ledgerEntryIdRaw.toString().trim() || null;

    return {
      targetAuthUid: payload.targetAuthUid,
      amountDelta: payload.amountDelta,
      newBalance: Number.isFinite(newBalance) ? newBalance : null,
      ledgerEntryId,
      status: 'adjusted',
      returnValue: result?.returnValue ?? null,
    };
  },
  logContextBuilder(result, payload) {
    const record = Array.isArray(result?.recordset) ? result.recordset[0] : undefined;
    const ledgerEntryIdRaw = record?.LedgerEntryId ?? result?.output?.LedgerEntryId ?? null;
    return {
      targetAuthUid: payload.targetAuthUid,
      actorAuthUid: payload.actorAuthUid,
      amountDelta: payload.amountDelta,
      newBalance: record?.NewBalance ?? result?.output?.NewBalance ?? null,
      ledgerEntryId: ledgerEntryIdRaw == null ? null : ledgerEntryIdRaw.toString().trim() || null,
    };
  },
  scopeContextBuilder(data, context, payload) {
    return {
      targetAuthUid: payload.targetAuthUid,
      callerUid: context.auth?.uid ?? null,
    };
  },
});

defineProcedure('storeListProducts', {
  region: DEFAULT_REGION,
  requireAppCheck: false,
  access: {
    resource: 'store.products',
    action: 'read',
  },
  parseInput(data = {}) {
    const parsedLimit = Number.parseInt(data.limit ?? data.pageSize ?? 50, 10);
    const limit = Number.isFinite(parsedLimit) && parsedLimit > 0 ? Math.min(parsedLimit, 200) : 50;
    const category = toTrimmedString(data.category);
    const normalizedStatus = toTrimmedString(data.status)?.toUpperCase() ?? null;
    const sellerTypeRaw = toTrimmedString(data.sellerType || data.source || null)?.toUpperCase();
    let sellerType = null;
    if (sellerTypeRaw && ['P2P', 'COMMUNITY', 'VENDOR'].includes(sellerTypeRaw)) {
      sellerType = sellerTypeRaw;
    }
    return {
      limit,
      category,
      status: normalizedStatus,
      sellerType,
    };
  },
  bind(request, payload) {
    request.input('Limit', mssql.Int, payload.limit ?? 50);
    request.input('Category', mssql.NVarChar(64), payload.category);
    request.input('Status', mssql.NVarChar(32), payload.status);
    request.input('SellerType', mssql.NVarChar(32), payload.sellerType);
  },
  async execute(request) {
    return request.execute('dbo.sp_Store_ListActiveProducts');
  },
  transform(result) {
    const recordset = Array.isArray(result?.recordset) ? result.recordset : [];
    return {
      products: recordset.map((row) => parseProductRecord(row)),
      total: recordset.length,
    };
  },
  scopeContextBuilder(payload, result) {
    return {
      filters: {
        limit: payload.limit,
        category: payload.category,
        status: payload.status,
        sellerType: payload.sellerType,
      },
      total: result?.total ?? 0,
    };
  },
});

defineProcedure('storeGetProduct', {
  region: DEFAULT_REGION,
  requireAppCheck: false,
  access: {
    resource: 'store.products',
    action: 'read',
  },
  parseInput(data = {}) {
    const productId = toTrimmedString(data.productId || data.id);
    if (!productId) {
      throw new functions.https.HttpsError('invalid-argument', 'missing_product_id');
    }
    return {
      productId,
    };
  },
  bind(request, payload) {
    request.input('ProductId', mssql.NVarChar(64), payload.productId);
  },
  async execute(request) {
    return request.execute('dbo.sp_Store_GetProduct');
  },
  transform(result) {
    const record = result?.recordset?.[0] ?? null;
    if (!record) {
      throw new functions.https.HttpsError('not-found', 'store_product_not_found');
    }
    return {
      product: parseProductRecord(record),
    };
  },
  scopeContextBuilder(payload) {
    return {
      productId: payload.productId,
    };
  },
});

defineProcedure('storeShareProduct', {
  region: DEFAULT_REGION,
  requireAppCheck: false,
  access: {
    resource: 'store.products',
    action: 'share',
  },
  parseInput(data = {}, context = {}) {
    const authUid = toTrimmedString(context.auth?.uid);
    if (!authUid) {
      throw new functions.https.HttpsError('unauthenticated', 'authentication_required');
    }

    const productId = toTrimmedString(data.productId || data.id);
    if (!productId) {
      throw new functions.https.HttpsError('invalid-argument', 'product_id_required');
    }

    const entryId = toTrimmedString(data.entryId || data.shareEntryId);
    if (!entryId) {
      throw new functions.https.HttpsError('invalid-argument', 'entry_id_required');
    }

    return {
      productId,
      entryId,
      requestedBy: authUid,
    };
  },
  bind(request, payload) {
    request.input('ProductId', mssql.NVarChar(64), payload.productId);
    request.input('EntryId', mssql.NVarChar(128), payload.entryId);
    request.input('RequestedBy', mssql.NVarChar(64), payload.requestedBy);
  },
  async execute(request) {
    return request.execute('dbo.sp_Store_RecordProductShare');
  },
  transform(result) {
    const record = result?.recordset?.[0];
    if (!record) {
      throw new functions.https.HttpsError('internal', 'share_product_no_result');
    }
    return {
      product: parseProductRecord(record),
    };
  },
  scopeContextBuilder(payload, result) {
    return {
      productId: payload.productId,
      entryId: payload.entryId,
      requestedBy: payload.requestedBy,
      sharedEntryId: result?.product?.sharedEntryId ?? null,
    };
  },
});

defineProcedure('storeGetWallet', {
  region: DEFAULT_REGION,
  requireAppCheck: false,
  access: {
    resource: 'store.wallets',
    action: 'read',
  },
  parseInput(data = {}, context = {}) {
    const authUid = toTrimmedString(data.authUid || data.targetAuthUid || context.auth?.uid);
    if (!authUid) {
      throw new functions.https.HttpsError('unauthenticated', 'missing_wallet_identity');
    }
    const createIfMissing = booleanFrom(data.createIfMissing ?? false);
    return {
      targetAuthUid: authUid,
      createIfMissing,
    };
  },
  bind(request, payload) {
    request.input('TargetAuthUid', mssql.NVarChar(64), payload.targetAuthUid);
    request.input('CreateIfMissing', mssql.Bit, payload.createIfMissing ? 1 : 0);
  },
  async execute(request) {
    return request.execute('dbo.sp_Store_GetWallet');
  },
  transform(result) {
    const walletRecord = result?.recordsets?.[0]?.[0] ?? result?.recordset?.[0] ?? null;
    const ledgerRecords = Array.isArray(result?.recordsets?.[1]) ? result.recordsets[1] : [];
    if (!walletRecord) {
      return {
        wallet: null,
        ledger: [],
      };
    }
    return {
      wallet: parseWalletRecord(walletRecord),
      ledger: ledgerRecords.map((row) => parseLedgerRecord(row)),
    };
  },
  scopeContextBuilder(payload, result) {
    return {
      targetAuthUid: payload.targetAuthUid,
      createIfMissing: payload.createIfMissing,
      walletFound: Boolean(result?.wallet),
      ledgerCount: result?.ledger?.length ?? 0,
    };
  },
});

defineProcedure('storeListOrdersForBuyer', {
  region: DEFAULT_REGION,
  requireAppCheck: false,
  access: {
    resource: 'store.orders',
    action: 'read',
  },
  parseInput(data = {}, context = {}) {
    const authUid = toTrimmedString(context.auth?.uid);
    const buyerAuthUid = toTrimmedString(data.buyerAuthUid || authUid);
    if (!buyerAuthUid || buyerAuthUid !== authUid) {
      throw new functions.https.HttpsError('permission-denied', 'orders_can_only_be_listed_for_requester');
    }
    const parsedLimit = Number.parseInt(data.limit ?? data.pageSize ?? 50, 10);
    const limit = Number.isFinite(parsedLimit) && parsedLimit > 0 ? Math.min(parsedLimit, 200) : 50;
    return {
      buyerAuthUid,
      limit,
    };
  },
  bind(request, payload) {
    request.input('BuyerAuthUid', mssql.NVarChar(64), payload.buyerAuthUid);
    request.input('Limit', mssql.Int, payload.limit ?? 50);
  },
  async execute(request) {
    return request.execute('dbo.sp_Store_ListOrdersForBuyer');
  },
  transform(result) {
    const recordset = Array.isArray(result?.recordset) ? result.recordset : [];
    return {
      orders: recordset.map((row) => parseOrderRecord(row)),
      total: recordset.length,
    };
  },
  scopeContextBuilder(payload, result) {
    return {
      buyerAuthUid: payload.buyerAuthUid,
      limit: payload.limit,
      total: result?.total ?? 0,
    };
  },
});

defineProcedure('storeRefundOrder', {
  region: DEFAULT_REGION,
  requireAppCheck: true,
  access: {
    resource: 'store.orders',
    action: 'refund',
  },
  parseInput(data = {}, context = {}) {
    const actorAuthUid = toTrimmedString(context.auth?.uid);
    if (!actorAuthUid) {
      throw new functions.https.HttpsError('unauthenticated', 'authentication_required');
    }

    const orderId = toTrimmedString(data.orderId || data.orderPublicId);
    if (!orderId) {
      throw new functions.https.HttpsError('invalid-argument', 'order_id_required');
    }

    const refundReason = toTrimmedString(data.refundReason || data.reason);
    const isSystemOverride = toBooleanFlag(data.isSystemOverride ?? data.override);

    return {
      orderId,
      actorAuthUid,
      refundReason: refundReason || null,
      isSystemOverride,
    };
  },
  bind(request, payload) {
    request.input('OrderPublicId', mssql.NVarChar(64), payload.orderId);
    request.input('ActorAuthUid', mssql.NVarChar(64), payload.actorAuthUid);
    request.input('RefundReason', mssql.NVarChar(256), payload.refundReason);
    request.input('IsSystemOverride', mssql.Bit, payload.isSystemOverride ? 1 : 0);
    request.output('RefundPublicId', mssql.NVarChar(64));
  },
  async execute(request) {
    return request.execute('dbo.sp_Store_RefundOrder');
  },
  transform(result, payload) {
    const refundPublicId = toTrimmedString(result?.output?.RefundPublicId);
    return {
      orderId: payload.orderId,
      refundId: refundPublicId || null,
      status: 'refunded',
      returnValue: result?.returnValue ?? null,
    };
  },
  logContextBuilder(result, payload) {
    return {
      orderId: payload.orderId,
      refundId: toTrimmedString(result?.output?.RefundPublicId) || null,
      actorAuthUid: payload.actorAuthUid,
      returnValue: result?.returnValue ?? null,
    };
  },
  scopeContextBuilder(data, context, payload) {
    return {
      orderId: payload.orderId,
      callerUid: context.auth?.uid ?? null,
    };
  },
});

defineProcedure('storeGetOrder', {
  region: DEFAULT_REGION,
  requireAppCheck: false,
  access: {
    resource: 'store.orders',
    action: 'read',
  },
  parseInput(data = {}, context = {}) {
    const orderId = toTrimmedString(data.orderId || data.orderPublicId);
    if (!orderId) {
      throw new functions.https.HttpsError('invalid-argument', 'order_id_required');
    }

    const authUid = toTrimmedString(context.auth?.uid);

    return {
      orderId,
      authUid: authUid || null,
    };
  },
  bind(request, payload) {
    request.input('OrderPublicId', mssql.NVarChar(64), payload.orderId);
  },
  async execute(request) {
    return request.execute('dbo.sp_Store_GetOrder');
  },
  transform(result, payload) {
    const orderRecord = result?.recordsets?.[0]?.[0] ?? result?.recordset?.[0] ?? null;
    
    if (!orderRecord) {
      return {
        order: null,
      };
    }

    const order = parseOrderRecord(orderRecord);

    // If there's auth context, verify the user has permission to view this order
    if (payload.authUid) {
      const canView = 
        order.buyerAuthUid === payload.authUid || 
        order.sellerAuthUid === payload.authUid;
      
      if (!canView) {
        throw new functions.https.HttpsError(
          'permission-denied', 
          'order_can_only_be_viewed_by_buyer_or_seller'
        );
      }
    }

    return {
      order,
    };
  },
  logContextBuilder(result, payload) {
    return {
      orderId: payload.orderId,
      orderFound: Boolean(result?.order),
      authUid: payload.authUid || null,
    };
  },
  scopeContextBuilder(data, context, payload) {
    return {
      orderId: payload.orderId,
      callerUid: context.auth?.uid ?? null,
    };
  },
});

defineProcedure('dmListConversations', {
  region: DEFAULT_REGION,
  requireAppCheck: true,
  access: {
    resource: 'dm.conversations',
    action: 'read',
  },
  parseInput(data = {}, context = {}) {
    const authUid = toTrimmedString(context.auth?.uid);
    if (!authUid) {
      throw new functions.https.HttpsError('unauthenticated', 'authentication_required');
    }

    const rawLimit = Number.parseInt(data.limit ?? data.pageSize ?? 20, 10);
    let limit = 20;
    if (Number.isFinite(rawLimit) && rawLimit > 0) {
      limit = Math.min(rawLimit, 100);
    }

    const updatedBeforeIso =
      toSafeIsoString(data.updatedBefore) ||
      toSafeIsoString(data.cursor) ||
      toSafeIsoString(data.beforeUpdatedAt) ||
      null;

    const beforeConversationId =
      toTrimmedString(
        data.beforeConversationId ||
          data.beforeConversationKey ||
          data.beforeConversationFirestoreId,
      ) || null;

    return {
      authUid,
      limit,
      updatedBeforeIso,
      beforeConversationId,
    };
  },
  bind(request, payload) {
    request.input('AuthUid', mssql.NVarChar(64), payload.authUid);
    request.input('Limit', mssql.Int, payload.limit ?? 20);
    const updatedBeforeDate = payload.updatedBeforeIso ? new Date(payload.updatedBeforeIso) : null;
    request.input('UpdatedBefore', mssql.DateTimeOffset, updatedBeforeDate);
    request.input(
      'BeforeConversationFirestoreId',
      mssql.NVarChar(128),
      payload.beforeConversationId,
    );
  },
  async execute(request) {
    return request.execute('dbo.sp_StoreMirror_ListDmConversations');
  },
  transform(result, payload) {
    const recordset = Array.isArray(result?.recordset) ? result.recordset : [];
    const conversations = recordset.map((row) => parseSqlConversationRecord(row));
    const lastRow = recordset[recordset.length - 1] || null;
    const nextCursor = lastRow ? toSafeIsoString(lastRow.UpdatedAt) : null;
    const nextConversationId = lastRow ? toTrimmedString(lastRow.ConversationFirestoreId) || null : null;

    return {
      conversations,
      nextCursor,
      nextConversationId,
      pageSize: payload.limit,
      resultCount: conversations.length,
    };
  },
  logContextBuilder(result, payload) {
    return {
      authUid: payload.authUid,
      limit: payload.limit,
      resultCount: result?.resultCount ?? 0,
      nextCursor: result?.nextCursor ?? null,
    };
  },
  scopeContextBuilder(data, context, payload) {
    return {
      authUid: payload.authUid,
      callerUid: context.auth?.uid ?? null,
    };
  },
});

defineProcedure('dmListMessages', {
  region: DEFAULT_REGION,
  requireAppCheck: true,
  access: {
    resource: 'dm.messages',
    action: 'read',
  },
  parseInput(data = {}, context = {}) {
    const authUid = toTrimmedString(context.auth?.uid);
    if (!authUid) {
      throw new functions.https.HttpsError('unauthenticated', 'authentication_required');
    }

    const conversationId =
      toTrimmedString(
        data.conversationId || data.conversationKey || data.conversationFirestoreId,
      ) || null;

    if (!conversationId) {
      throw new functions.https.HttpsError('invalid-argument', 'conversation_id_required');
    }

    const rawLimit = Number.parseInt(data.limit ?? data.pageSize ?? 50, 10);
    let limit = 50;
    if (Number.isFinite(rawLimit) && rawLimit > 0) {
      limit = Math.min(rawLimit, 200);
    }

    const beforeTimestampIso =
      toSafeIsoString(data.beforeTimestamp) ||
      toSafeIsoString(data.before) ||
      toSafeIsoString(data.cursor) ||
      null;

    const beforeMessageId =
      toTrimmedString(
        data.beforeMessageId || data.beforeMessageFirestoreId || data.cursorMessageId,
      ) || null;

    return {
      authUid,
      conversationId,
      limit,
      beforeTimestampIso,
      beforeMessageId,
    };
  },
  bind(request, payload) {
    request.input('AuthUid', mssql.NVarChar(64), payload.authUid);
    request.input('ConversationFirestoreId', mssql.NVarChar(128), payload.conversationId);
    request.input('Limit', mssql.Int, payload.limit ?? 50);
    const beforeTimestamp = payload.beforeTimestampIso ? new Date(payload.beforeTimestampIso) : null;
    request.input('BeforeTimestamp', mssql.DateTimeOffset, beforeTimestamp);
    request.input('BeforeMessageFirestoreId', mssql.NVarChar(128), payload.beforeMessageId);
  },
  async execute(request) {
    return request.execute('dbo.sp_StoreMirror_ListDmMessages');
  },
  transform(result, payload) {
    const recordset = Array.isArray(result?.recordset) ? result.recordset : [];
    const messages = recordset.map((row) => parseSqlDmMessageRecord(row));
    const lastRow = recordset[recordset.length - 1] || null;
    const nextCursor = lastRow ? toSafeIsoString(lastRow.CreatedAt) : null;
    const nextMessageId = lastRow ? toTrimmedString(lastRow.MessageFirestoreId) || null : null;

    return {
      messages,
      nextCursor,
      nextMessageId,
      pageSize: payload.limit,
      resultCount: messages.length,
      conversationId: payload.conversationId,
    };
  },
  logContextBuilder(result, payload) {
    return {
      authUid: payload.authUid,
      conversationId: payload.conversationId,
      limit: payload.limit,
      resultCount: result?.resultCount ?? 0,
      nextCursor: result?.nextCursor ?? null,
    };
  },
  scopeContextBuilder(data, context, payload) {
    return {
      conversationId: payload.conversationId,
      authUid: payload.authUid,
      callerUid: context.auth?.uid ?? null,
    };
  },
});

defineProcedure('followGetRelationship', {
  region: DEFAULT_REGION,
  requireAppCheck: true,
  access: {
    resource: 'follow.edge',
    action: 'read',
  },
  parseInput(data = {}, context = {}) {
    const authUid = toTrimmedString(context.auth?.uid);
    if (!authUid) {
      throw new functions.https.HttpsError('unauthenticated', 'authentication_required');
    }

    const viewerUid =
      toTrimmedString(data.viewerUid || data.viewerId || data.authUid || data.userId) || authUid;

    if (viewerUid !== authUid) {
      throw new functions.https.HttpsError('permission-denied', 'viewer_mismatch');
    }

    const targetUid = toTrimmedString(
      data.targetUid || data.targetId || data.otherUid || data.partnerUid || data.userId
    );

    if (!targetUid) {
      throw new functions.https.HttpsError('invalid-argument', 'target_uid_required');
    }

    return {
      viewerUid,
      targetUid,
    };
  },
  bind(request, payload) {
    request.input('ViewerUserId', mssql.NVarChar(64), payload.viewerUid);
    request.input('TargetUserId', mssql.NVarChar(64), payload.targetUid);
  },
  async execute(request) {
    return request.execute('dbo.sp_StoreMirror_GetFollowRelationship');
  },
  transform(result, payload) {
    const rows = Array.isArray(result?.recordset) ? result.recordset : [];
    const blockRows = Array.isArray(result?.recordsets?.[1]) ? result.recordsets[1] : [];
    const normalizeDirection = (value) => toTrimmedString(value)?.toLowerCase() || '';
    const outgoingRow = rows.find((row) => normalizeDirection(row.Direction) === 'outgoing');
    const incomingRow = rows.find((row) => normalizeDirection(row.Direction) === 'incoming');
    const outgoingBlockRow = blockRows.find((row) => normalizeDirection(row.Direction) === 'outgoing');
    const incomingBlockRow = blockRows.find((row) => normalizeDirection(row.Direction) === 'incoming');

    const relationship = {
      outgoing: outgoingRow
        ? parseSqlFollowEdgeRecord(outgoingRow, 'followGetRelationship.outgoing')
        : null,
      incoming: incomingRow
        ? parseSqlFollowEdgeRecord(incomingRow, 'followGetRelationship.incoming')
        : null,
      outgoingBlock: outgoingBlockRow
        ? parseSqlBlockEdgeRecord(outgoingBlockRow, 'followGetRelationship.block.outgoing')
        : null,
      incomingBlock: incomingBlockRow
        ? parseSqlBlockEdgeRecord(incomingBlockRow, 'followGetRelationship.block.incoming')
        : null,
    };

    return {
      relationship,
    };
  },
  logContextBuilder(result, payload) {
    return {
      viewerUid: payload.viewerUid,
      targetUid: payload.targetUid,
      hasOutgoing: Boolean(result?.relationship?.outgoing),
      hasIncoming: Boolean(result?.relationship?.incoming),
      hasOutgoingBlock: Boolean(result?.relationship?.outgoingBlock),
      hasIncomingBlock: Boolean(result?.relationship?.incomingBlock),
    };
  },
  scopeContextBuilder(data, context, payload) {
    return {
      viewerUid: payload.viewerUid,
      targetUid: payload.targetUid,
      callerUid: context.auth?.uid ?? null,
    };
  },
});

defineProcedure('dmSend', {
  region: DEFAULT_REGION,
  requireAppCheck: true,
  parseInput(data = {}, context = {}) {
    const authUid = toTrimmedString(context.auth?.uid);
    if (!authUid) {
      throw new functions.https.HttpsError('unauthenticated', 'authentication_required');
    }

    if (!data || typeof data !== 'object') {
      throw new functions.https.HttpsError('invalid-argument', 'event_envelope_required');
    }

    const type = toTrimmedString(data.type);
    if (!type || !type.startsWith('dm.message.')) {
      throw new functions.https.HttpsError('invalid-argument', 'invalid_event_type');
    }

    const eventData = data.data && typeof data.data === 'object' ? data.data : null;
    if (!eventData) {
      throw new functions.https.HttpsError('invalid-argument', 'event_data_required');
    }

    const operation = toTrimmedString(eventData.operation) || 'create';
    const conversationId = toTrimmedString(eventData.conversationId);
    const messageId = toTrimmedString(eventData.messageId) || toTrimmedString(eventData.clientMessageId);

    if (!conversationId) {
      throw new functions.https.HttpsError('invalid-argument', 'conversation_id_required');
    }

    if (!messageId) {
      throw new functions.https.HttpsError('invalid-argument', 'message_id_required');
    }

    const senderId = toTrimmedString(eventData.senderId) || authUid;
    if (senderId !== authUid) {
      throw new functions.https.HttpsError('permission-denied', 'sender_mismatch');
    }

    const document = eventData.document && typeof eventData.document === 'object' ? eventData.document : null;
    if (!document) {
      throw new functions.https.HttpsError('invalid-argument', 'document_required');
    }

    const previousDocument =
      eventData.previousDocument && typeof eventData.previousDocument === 'object'
        ? eventData.previousDocument
        : null;

    const eventId = toTrimmedString(data.id) || `dmSend:${conversationId}:${messageId}:${Date.now()}`;
    const source = toTrimmedString(data.source) || 'client://dm/send';
    const eventTimestampIso =
      toSafeIsoString(data.time) || toSafeIsoString(eventData.timestamp) || new Date().toISOString();

    const metadata = {
      operation,
      conversationId,
      messageId,
      clientMessageId: toTrimmedString(eventData.clientMessageId) || messageId,
      senderId,
      recipientId: toTrimmedString(eventData.recipientId) || null,
      participantMeta: eventData.participantMeta ?? null,
      source,
      attachments: Array.isArray(eventData.attachments) ? eventData.attachments : null,
    };

    return {
      eventType: type,
      operation,
      source,
      eventId,
      eventTimestampIso,
      document,
      previousDocument,
      metadata,
    };
  },
  bind(request, payload) {
    request.input('EventType', mssql.NVarChar(64), payload.eventType);
    request.input('Operation', mssql.NVarChar(32), payload.operation);
    request.input('Source', mssql.NVarChar(256), payload.source);
    request.input('EventId', mssql.NVarChar(128), payload.eventId);
    const timestamp = payload.eventTimestampIso ? new Date(payload.eventTimestampIso) : new Date();
    request.input('EventTimestamp', mssql.DateTimeOffset, timestamp);
    request.input('DocumentJson', mssql.NVarChar(mssql.MAX), JSON.stringify(payload.document ?? null));
    request.input(
      'PreviousDocumentJson',
      mssql.NVarChar(mssql.MAX),
      payload.previousDocument ? JSON.stringify(payload.previousDocument) : null
    );
    request.input('MetadataJson', mssql.NVarChar(mssql.MAX), JSON.stringify(payload.metadata ?? {}));
  },
  async execute(request) {
    return request.execute('dbo.sp_StoreMirror_UpsertDmMessage');
  },
  transform(result, payload) {
    const affected = Array.isArray(result?.rowsAffected)
      ? result.rowsAffected.reduce((sum, value) => sum + (Number.isFinite(value) ? value : 0), 0)
      : 0;
    return {
      ok: true,
      rowsAffected: affected,
      eventId: payload.eventId,
    };
  },
  logContextBuilder(result, payload) {
    return {
      conversationId: payload.metadata?.conversationId ?? null,
      messageId: payload.metadata?.messageId ?? null,
      operation: payload.operation,
      eventId: payload.eventId,
      rowsAffected: result?.rowsAffected ?? null,
    };
  },
  scopeContextBuilder(data, context, payload) {
    return {
      conversationId: payload.metadata?.conversationId ?? null,
      messageId: payload.metadata?.messageId ?? null,
      senderId: payload.metadata?.senderId ?? context.auth?.uid ?? null,
    };
  },
});

defineProcedure('followEdgeUpsert', {
  region: DEFAULT_REGION,
  requireAppCheck: true,
  parseInput(data = {}, context = {}) {
    const authUid = toTrimmedString(context.auth?.uid);
    if (!authUid) {
      throw new functions.https.HttpsError('unauthenticated', 'authentication_required');
    }

    if (!data || typeof data !== 'object') {
      throw new functions.https.HttpsError('invalid-argument', 'event_envelope_required');
    }

    const type = toTrimmedString(data.type);
    if (!type || !type.startsWith('follow.edge.')) {
      throw new functions.https.HttpsError('invalid-argument', 'invalid_event_type');
    }

    const eventData = data.data && typeof data.data === 'object' ? data.data : null;
    if (!eventData) {
      throw new functions.https.HttpsError('invalid-argument', 'event_data_required');
    }

    const operation = toTrimmedString(eventData.operation) || type.split('.').pop() || 'update';
    const userId = toTrimmedString(eventData.userId);
    const targetId = toTrimmedString(eventData.targetId);

    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'user_id_required');
    }

    if (!targetId) {
      throw new functions.https.HttpsError('invalid-argument', 'target_id_required');
    }

    if (authUid !== userId) {
      throw new functions.https.HttpsError('permission-denied', 'user_mismatch');
    }

    const document = eventData.document && typeof eventData.document === 'object' ? eventData.document : null;
    const previousDocument =
      eventData.previousDocument && typeof eventData.previousDocument === 'object'
        ? eventData.previousDocument
        : null;

    const eventId = toTrimmedString(data.id) || `followEdgeUpsert:${userId}:${targetId}:${Date.now()}`;
    const source = toTrimmedString(data.source) || 'client://follow/upsert';
    const eventTimestampIso =
      toSafeIsoString(data.time) || toSafeIsoString(eventData.timestamp) || new Date().toISOString();

    const metadata = {
      operation,
      userId,
      targetId,
      source,
    };

    return {
      eventType: type,
      operation,
      source,
      eventId,
      eventTimestampIso,
      document,
      previousDocument,
      metadata,
    };
  },
  bind(request, payload) {
    request.input('EventType', mssql.NVarChar(64), payload.eventType);
    request.input('Operation', mssql.NVarChar(32), payload.operation);
    request.input('Source', mssql.NVarChar(256), payload.source);
    request.input('EventId', mssql.NVarChar(128), payload.eventId);
    const timestamp = payload.eventTimestampIso ? new Date(payload.eventTimestampIso) : new Date();
    request.input('EventTimestamp', mssql.DateTimeOffset, timestamp);
    request.input('DocumentJson', mssql.NVarChar(mssql.MAX), JSON.stringify(payload.document ?? null));
    request.input(
      'PreviousDocumentJson',
      mssql.NVarChar(mssql.MAX),
      payload.previousDocument ? JSON.stringify(payload.previousDocument) : null
    );
    request.input('MetadataJson', mssql.NVarChar(mssql.MAX), JSON.stringify(payload.metadata ?? {}));
  },
  async execute(request) {
    return request.execute('dbo.sp_StoreMirror_UpsertFollowEdge');
  },
  transform(result, payload) {
    const affected = Array.isArray(result?.rowsAffected)
      ? result.rowsAffected.reduce((sum, value) => sum + (Number.isFinite(value) ? value : 0), 0)
      : 0;
    return {
      ok: true,
      rowsAffected: affected,
      eventId: payload.eventId,
    };
  },
  logContextBuilder(result, payload) {
    return {
      userId: payload.metadata?.userId ?? null,
      targetId: payload.metadata?.targetId ?? null,
      operation: payload.operation,
      eventId: payload.eventId,
      rowsAffected: result?.rowsAffected ?? null,
    };
  },
  scopeContextBuilder(data, context, payload) {
    return {
      userId: payload.metadata?.userId ?? context.auth?.uid ?? null,
      targetId: payload.metadata?.targetId ?? null,
      operation: payload.operation,
    };
  },
});

module.exports = {
  getProcedure,
  listProcedureKeys,
};
