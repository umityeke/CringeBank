// ========================================
// CRINGESTORE CLOUD FUNCTIONS
// Full Security Escrow System
// Region: europe-west1
// ========================================

const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { hasAnyRole } = require('./utils/claims');
const { executeProcedure } = require('./sql_gateway');
const { getProcedure } = require('./sql_gateway/procedures');

// Region konfigürasyonu
const region = 'europe-west1';
const ESCROW_ADMIN_ROLES = Object.freeze(['superadmin', 'system_writer']);
const USE_SQL_ESCROW_GATEWAY_FLAG = process.env.USE_SQL_ESCROW_GATEWAY;
const USE_SQL_ESCROW_GATEWAY = USE_SQL_ESCROW_GATEWAY_FLAG === undefined ? true : USE_SQL_ESCROW_GATEWAY_FLAG === 'true';

const SQL_ERROR_TRANSLATIONS = Object.freeze({
  insufficient_balance: {
    code: 'failed-precondition',
    message: 'Yetersiz bakiye',
  },
  product_not_found: {
    code: 'not-found',
    message: 'Ürün bulunamadı',
  },
  order_not_found: {
    code: 'not-found',
    message: 'Sipariş bulunamadı',
  },
  order_not_pending: {
    code: 'failed-precondition',
    message: 'Sipariş uygun durumda değil',
  },
  escrow_not_locked: {
    code: 'failed-precondition',
    message: 'Escrow kilitli değil',
  },
  escrow_already_released: {
    code: 'failed-precondition',
    message: 'Escrow zaten serbest bırakılmış',
  },
  wallet_not_found: {
    code: 'not-found',
    message: 'Cüzdan bulunamadı',
  },
  unauthorized_actor: {
    code: 'permission-denied',
    message: 'Bu işlemi yapmaya yetkiniz yok',
  },
  unique_constraint_violation: {
    code: 'already-exists',
    message: 'Kayıt zaten mevcut',
  },
  constraint_violation: {
    code: 'failed-precondition',
    message: 'İşlem kısıtlamaya takıldı',
  },
  sql_login_failed: {
    code: 'failed-precondition',
    message: 'SQL oturumu açılamadı',
  },
  sql_timeout: {
    code: 'deadline-exceeded',
    message: 'SQL isteği zaman aşımına uğradı',
  },
  sql_no_result_returned: {
    code: 'internal',
    message: 'SQL sonucu alınamadı',
  },
  sql_gateway_failure: {
    code: 'internal',
    message: 'SQL gateway hatası',
  },
  sql_gateway_product_id_required: {
    code: 'invalid-argument',
    message: 'Ürün kimliği gerekli',
  },
  sql_gateway_entry_id_required: {
    code: 'invalid-argument',
    message: 'Paylaşım kaydı kimliği gerekli',
  },
  sql_gateway_auth_required: {
    code: 'unauthenticated',
    message: 'Paylaşım için oturum açmanız gerekiyor',
  },
  sql_gateway_product_not_found: {
    code: 'not-found',
    message: 'Ürün bulunamadı',
  },
  sql_gateway_already_shared: {
    code: 'already-exists',
    message: 'Ürün zaten paylaşılmış',
  },
  sql_gateway_share_invalid_status: {
    code: 'failed-precondition',
    message: 'Sadece satışı tamamlanan ürünler paylaşılabilir',
  },
  sql_gateway_share_only_p2p: {
    code: 'failed-precondition',
    message: 'Paylaşım sadece P2P ürünler için yapılabilir',
  },
  sql_gateway_share_unauthorized: {
    code: 'permission-denied',
    message: 'Bu ürünü paylaşma yetkiniz yok',
  },
  sql_gateway_share_update_failed: {
    code: 'internal',
    message: 'Paylaşım güncellenemedi, lütfen tekrar deneyin',
  },
});

function isEscrowAdmin(context) {
  return hasAnyRole(context, ESCROW_ADMIN_ROLES);
}

// ==================== HELPER FUNCTIONS ====================

/**
 * Komisyon hesapla (örnek: %5)
 */
function calculateCommission(amount) {
  const COMMISSION_RATE = 0.05; // %5 komisyon
  return Math.floor(amount * COMMISSION_RATE);
}

/**
 * Kullanıcı doğrulama
 */
function requireAuth(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Bu işlem için giriş yapmalısınız'
    );
  }
  return context.auth.uid;
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

function requireEscrowAdmin(context) {
  if (!isEscrowAdmin(context)) {
    throw new functions.https.HttpsError('permission-denied', 'Bu işlemi yapmaya yetkiniz yok');
  }
  return context.auth?.uid ?? null;
}

function parseGoldDelta(value, fieldName = 'amount') {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new functions.https.HttpsError('invalid-argument', `${fieldName} sayısal olmalı`);
  }
  const rounded = Math.round(parsed);
  if (rounded === 0) {
    throw new functions.https.HttpsError('invalid-argument', `${fieldName} sıfır olamaz`);
  }
  return rounded;
}

function normalizeSqlReason(reason) {
  if (!reason) {
    return 'sql_gateway_failure';
  }
  const normalized = reason.toString().trim().toLowerCase();
  if (normalized.startsWith('sp_store_recordproductshare failed')) {
    return 'sql_gateway_share_update_failed';
  }
  return normalized;
}

function buildSqlErrorLogContext(operation, error, context, reason) {
  const base = {
    operation,
    uid: context?.auth?.uid ?? null,
    appCheck: Boolean(context?.app),
    reason,
  };

  if (error?.sqlGatewayMeta?.sql) {
    base.sql = error.sqlGatewayMeta.sql;
  } else if (typeof error?.details === 'object' && error.details?.sql) {
    base.sql = error.details.sql;
  }

  if (error?.code) {
    base.code = error.code;
  }

  return base;
}

function mapSqlGatewayError(error, operation, context) {
  if (!(error instanceof functions.https.HttpsError)) {
    functions.logger.error('cringeStore.sql_gateway_unexpected_error', {
      operation,
      uid: context?.auth?.uid ?? null,
      message: error?.message,
    });
    return new functions.https.HttpsError('internal', 'sql_gateway_failure');
  }

  const details = typeof error.details === 'object' && error.details !== null ? { ...error.details } : {};
  const extractedReason = details.reason || error.sqlGatewayMeta?.reason || error.message;
  const reason = normalizeSqlReason(extractedReason);
  const translation = SQL_ERROR_TRANSLATIONS[reason];

  if (!translation) {
    functions.logger.warn('cringeStore.sql_gateway_unmapped_reason', buildSqlErrorLogContext(operation, error, context, reason));
    return error;
  }

  functions.logger.warn('cringeStore.sql_gateway_error', {
    ...buildSqlErrorLogContext(operation, error, context, reason),
    mappedCode: translation.code,
  });

  return new functions.https.HttpsError(translation.code, translation.message, {
    ...details,
    reason,
  });
}

async function executeFirestoreFallback(operation, handler, context) {
  functions.logger.warn('cringeStore.firestore_fallback', {
    operation,
    uid: context?.auth?.uid ?? null,
  });

  try {
    const result = await handler();
    return result;
  } catch (error) {
    functions.logger.error('cringeStore.firestore_fallback_error', {
      operation,
      uid: context?.auth?.uid ?? null,
      message: error?.message,
    });

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError('internal', error?.message || 'firestore_fallback_error');
  }
}

async function withSqlGateway(operation, sqlHandler, firestoreHandler, context) {
  if (!USE_SQL_ESCROW_GATEWAY) {
    if (typeof firestoreHandler !== 'function') {
      throw new functions.https.HttpsError('unavailable', 'sql_gateway_disabled');
    }

    return executeFirestoreFallback(operation, firestoreHandler, context);
  }

  try {
    const result = await sqlHandler();
    return result;
  } catch (error) {
    throw mapSqlGatewayError(error, operation, context);
  }
}

async function executeStoreGatewayProcedure(key, rawData, context) {
  const definition = getProcedure(key);

  if (!definition) {
    throw new functions.https.HttpsError('failed-precondition', 'sql_gateway_definition_missing');
  }

  if (definition.requireAppCheck !== false && !context.app) {
    throw new functions.https.HttpsError('failed-precondition', 'app_check_required');
  }

  const payload = definition.parseInput ? definition.parseInput(rawData, context) : rawData || {};

  try {
    return await executeProcedure(key, payload, context);
  } catch (error) {
    throw mapSqlGatewayError(error, key, context);
  }
}

async function escrowLockSql(data, context) {
  const buyerId = requireAuth(context);
  const productId = toTrimmedString(data?.productId);

  if (!productId) {
    throw new functions.https.HttpsError('invalid-argument', 'productId gerekli');
  }

  const isOverride = isEscrowAdmin(context) && toBooleanFlag(data?.isSystemOverride ?? data?.override);
  const commissionRate = data?.commissionRate;

  const response = await executeStoreGatewayProcedure(
    'storeCreateOrder',
    {
      productId,
      commissionRate,
      requestedBy: buyerId,
      isSystemOverride: isOverride,
    },
    context
  );

  return {
    ok: true,
    orderId: response?.orderId,
  };
}

async function escrowLockFirestore(data, context) {
  const db = admin.firestore();

  const buyerId = requireAuth(context);
  const productId = toTrimmedString(data?.productId);

  if (!productId) {
    throw new functions.https.HttpsError('invalid-argument', 'productId gerekli');
  }

  const result = await db.runTransaction(async (transaction) => {
    const productRef = db.collection('store_products').doc(productId);
    const productDoc = await transaction.get(productRef);

    if (!productDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Ürün bulunamadı');
    }

    const product = productDoc.data();

    if (product.status !== 'active') {
      throw new functions.https.HttpsError('failed-precondition', 'Ürün aktif değil');
    }

    if (product.sellerId === buyerId) {
      throw new functions.https.HttpsError('failed-precondition', 'Kendi ürününüzü satın alamazsınız');
    }

    const priceGold = product.priceGold;
    const commissionGold = calculateCommission(priceGold);
    const totalCost = priceGold + commissionGold;

    const walletRef = db.collection('store_wallets').doc(buyerId);
    const walletDoc = await transaction.get(walletRef);

    let currentBalance = 0;
    if (walletDoc.exists) {
      currentBalance = walletDoc.data().goldBalance || 0;
    }

    if (currentBalance < totalCost) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Yetersiz bakiye. Gerekli: ${totalCost} Altın, Mevcut: ${currentBalance} Altın`
      );
    }

    const orderRef = db.collection('store_orders').doc();
    const orderId = orderRef.id;
    const now = admin.firestore.FieldValue.serverTimestamp();

    const orderData = {
      orderId,
      productId,
      buyerId,
      sellerId: product.sellerId || product.vendorId,
      sellerType: product.sellerType,
      priceGold,
      commissionGold,
      totalGold: totalCost,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    };

    transaction.set(orderRef, orderData);

    const escrowRef = db.collection('store_escrows').doc(orderId);
    const escrowData = {
      orderId,
      buyerId,
      sellerId: product.sellerId || product.vendorId,
      amountGold: totalCost,
      status: 'locked',
      createdAt: now,
    };

    transaction.set(escrowRef, escrowData);

    const newBalance = currentBalance - totalCost;
    if (walletDoc.exists) {
      transaction.update(walletRef, {
        goldBalance: newBalance,
        updatedAt: now,
      });
    } else {
      transaction.set(walletRef, {
        userId: buyerId,
        goldBalance: newBalance,
        createdAt: now,
        updatedAt: now,
      });
    }

    transaction.update(productRef, {
      status: 'reserved',
      reservedBy: buyerId,
      reservedAt: now,
      updatedAt: now,
    });

    return orderId;
  });

  return { ok: true, orderId: result };
}

async function escrowReleaseSql(data, context) {
  requireAuth(context);
  const orderId = toTrimmedString(data?.orderId || data?.orderPublicId);

  if (!orderId) {
    throw new functions.https.HttpsError('invalid-argument', 'orderId gerekli');
  }

  const isOverride = isEscrowAdmin(context) && toBooleanFlag(data?.isSystemOverride ?? data?.override);

  await executeStoreGatewayProcedure(
    'storeReleaseEscrow',
    {
      orderId,
      isSystemOverride: isOverride,
    },
    context
  );

  return {
    ok: true,
  };
}

async function escrowReleaseFirestore(data, context) {
  const db = admin.firestore();

  const userId = requireAuth(context);
  const orderId = toTrimmedString(data?.orderId);

  if (!orderId) {
    throw new functions.https.HttpsError('invalid-argument', 'orderId gerekli');
  }

  const isAdmin = isEscrowAdmin(context);

  await db.runTransaction(async (transaction) => {
    const orderRef = db.collection('store_orders').doc(orderId);
    const orderDoc = await transaction.get(orderRef);

    if (!orderDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Sipariş bulunamadı');
    }

    const order = orderDoc.data();

    if (order.buyerId !== userId && !isAdmin) {
      throw new functions.https.HttpsError('permission-denied', 'Bu işlemi yapmaya yetkiniz yok');
    }

    if (order.status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 'Sipariş pending durumunda değil');
    }

    const escrowRef = db.collection('store_escrows').doc(orderId);
    const escrowDoc = await transaction.get(escrowRef);

    if (!escrowDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Escrow bulunamadı');
    }

    const escrow = escrowDoc.data();

    if (escrow.status !== 'locked') {
      throw new functions.https.HttpsError('failed-precondition', 'Escrow locked durumunda değil');
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const sellerAmount = order.priceGold;
    const commissionAmount = order.commissionGold;

    const sellerWalletRef = db.collection('store_wallets').doc(order.sellerId);
    const sellerWalletDoc = await transaction.get(sellerWalletRef);

    let sellerBalance = 0;
    if (sellerWalletDoc.exists) {
      sellerBalance = sellerWalletDoc.data().goldBalance || 0;
    }

    const newSellerBalance = sellerBalance + sellerAmount;

    if (sellerWalletDoc.exists) {
      transaction.update(sellerWalletRef, {
        goldBalance: newSellerBalance,
        updatedAt: now,
      });
    } else {
      transaction.set(sellerWalletRef, {
        userId: order.sellerId,
        goldBalance: newSellerBalance,
        createdAt: now,
        updatedAt: now,
      });
    }

    const platformWalletRef = db.collection('store_wallets').doc('platform');
    const platformWalletDoc = await transaction.get(platformWalletRef);

    let platformBalance = 0;
    if (platformWalletDoc.exists) {
      platformBalance = platformWalletDoc.data().goldBalance || 0;
    }

    const newPlatformBalance = platformBalance + commissionAmount;

    if (platformWalletDoc.exists) {
      transaction.update(platformWalletRef, {
        goldBalance: newPlatformBalance,
        updatedAt: now,
      });
    } else {
      transaction.set(platformWalletRef, {
        userId: 'platform',
        goldBalance: newPlatformBalance,
        createdAt: now,
        updatedAt: now,
      });
    }

    transaction.update(orderRef, {
      status: 'completed',
      completedAt: now,
      updatedAt: now,
    });

    transaction.update(escrowRef, {
      status: 'released',
      releasedAt: now,
    });

    const productRef = db.collection('store_products').doc(order.productId);
    transaction.update(productRef, {
      status: 'sold',
      soldTo: order.buyerId,
      soldAt: now,
      updatedAt: now,
    });
  });

  return { ok: true };
}

async function escrowRefundSql(data, context) {
  requireAuth(context);
  const orderId = toTrimmedString(data?.orderId || data?.orderPublicId);

  if (!orderId) {
    throw new functions.https.HttpsError('invalid-argument', 'orderId gerekli');
  }

  const isOverride = isEscrowAdmin(context) && toBooleanFlag(data?.isSystemOverride ?? data?.override);
  const refundReason = toTrimmedString(data?.refundReason);

  await executeStoreGatewayProcedure(
    'storeRefundEscrow',
    {
      orderId,
      isSystemOverride: isOverride,
      refundReason: refundReason || null,
    },
    context
  );

  return {
    ok: true,
  };
}

async function escrowRefundFirestore(data, context) {
  const db = admin.firestore();

  const userId = requireAuth(context);
  const orderId = toTrimmedString(data?.orderId);

  if (!orderId) {
    throw new functions.https.HttpsError('invalid-argument', 'orderId gerekli');
  }

  const isAdmin = isEscrowAdmin(context);

  await db.runTransaction(async (transaction) => {
    const orderRef = db.collection('store_orders').doc(orderId);
    const orderDoc = await transaction.get(orderRef);

    if (!orderDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Sipariş bulunamadı');
    }

    const order = orderDoc.data();

    if (order.buyerId !== userId && order.sellerId !== userId && !isAdmin) {
      throw new functions.https.HttpsError('permission-denied', 'Bu işlemi yapmaya yetkiniz yok');
    }

    if (order.status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 'Sipariş pending durumunda değil');
    }

    const escrowRef = db.collection('store_escrows').doc(orderId);
    const escrowDoc = await transaction.get(escrowRef);

    if (!escrowDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Escrow bulunamadı');
    }

    const escrow = escrowDoc.data();

    if (escrow.status !== 'locked') {
      throw new functions.https.HttpsError('failed-precondition', 'Escrow locked durumunda değil');
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const refundAmount = order.totalGold;

    const buyerWalletRef = db.collection('store_wallets').doc(order.buyerId);
    const buyerWalletDoc = await transaction.get(buyerWalletRef);

    if (!buyerWalletDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Alıcı cüzdanı bulunamadı');
    }

    const buyerBalance = buyerWalletDoc.data().goldBalance || 0;
    const newBuyerBalance = buyerBalance + refundAmount;

    transaction.update(buyerWalletRef, {
      goldBalance: newBuyerBalance,
      updatedAt: now,
    });

    transaction.update(orderRef, {
      status: 'canceled',
      canceledAt: now,
      canceledBy: userId,
      updatedAt: now,
    });

    transaction.update(escrowRef, {
      status: 'refunded',
      refundedAt: now,
    });

    const productRef = db.collection('store_products').doc(order.productId);
    transaction.update(productRef, {
      status: 'active',
      reservedBy: admin.firestore.FieldValue.delete(),
      reservedAt: admin.firestore.FieldValue.delete(),
      updatedAt: now,
    });
  });

  return { ok: true };
}

async function walletAdjustSql(data, context) {
  requireAuth(context);
  const actorUid = requireEscrowAdmin(context);

  const targetAuthUid = toTrimmedString(
    data?.targetAuthUid ?? data?.targetUid ?? data?.targetUserId ?? data?.userId
  );

  if (!targetAuthUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUserId gerekli');
  }

  const amountDelta = parseGoldDelta(data?.amount ?? data?.amountDelta ?? data?.delta, 'amount');
  const reason = toTrimmedString(data?.reason);
  const metadata = data?.metadata ?? null;
  const isOverride = toBooleanFlag(data?.isSystemOverride ?? data?.override ?? true);

  const response = await executeStoreGatewayProcedure(
    'storeAdjustWallet',
    {
      targetAuthUid,
      amountDelta,
      reason: reason || null,
      metadata,
      isSystemOverride: isOverride,
    },
    context
  );

  return {
    ok: true,
    targetAuthUid,
    amountDelta,
    newBalance: response?.newBalance ?? null,
    actorAuthUid: actorUid,
  };
}

async function walletAdjustFirestore(data, context) {
  const actorUid = requireAuth(context);
  requireEscrowAdmin(context);

  const targetUserId = toTrimmedString(
    data?.targetAuthUid ?? data?.targetUid ?? data?.targetUserId ?? data?.userId
  );

  if (!targetUserId) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUserId gerekli');
  }

  const amountDelta = parseGoldDelta(data?.amount ?? data?.amountDelta ?? data?.delta, 'amount');
  const reason = toTrimmedString(data?.reason);
  const metadata = data?.metadata ?? null;

  const db = admin.firestore();

  const result = await db.runTransaction(async (transaction) => {
    const walletRef = db.collection('store_wallets').doc(targetUserId);
    const walletSnap = await transaction.get(walletRef);
    const now = admin.firestore.FieldValue.serverTimestamp();

    const currentBalance = walletSnap.exists ? walletSnap.data().goldBalance || 0 : 0;

    if (!walletSnap.exists && amountDelta < 0) {
      throw new functions.https.HttpsError('failed-precondition', 'Negatif ayarlama için cüzdan bulunamadı');
    }

    const newBalance = currentBalance + amountDelta;

    if (walletSnap.exists) {
      transaction.update(walletRef, {
        goldBalance: newBalance,
        updatedAt: now,
      });
    } else {
      transaction.set(walletRef, {
        userId: targetUserId,
        goldBalance: newBalance,
        createdAt: now,
        updatedAt: now,
      });
    }

    const ledgerRef = db.collection('store_wallet_ledger').doc();
    transaction.set(ledgerRef, {
      userId: targetUserId,
      amount: amountDelta,
      balanceAfter: newBalance,
      reason: reason || null,
      metadata: metadata ?? null,
      actorUid,
      type: 'adjustment',
      createdAt: now,
    });

    return {
      newBalance,
      ledgerEntryId: ledgerRef.id,
    };
  });

  return {
    ok: true,
    targetAuthUid: targetUserId,
    amountDelta,
    newBalance: result.newBalance,
    actorAuthUid: actorUid,
    ledgerEntryId: result.ledgerEntryId,
  };
}

// ==================== ESCROW LOCK ====================
/**
 * Satın alma başlat - Escrow kilitle
 * 
 * Input: { productId: string }
 * Output: { ok: true, orderId: string } | { ok: false, error: string }
 * 
 * İşlem:
 * 1. Ürünü kontrol et (aktif mi, fiyat nedir)
 * 2. Alıcının bakiyesi yeterli mi kontrol et
 * 3. Escrow oluştur ve parayı kilitle
 * 4. Alıcının bakiyesinden düş
 * 5. Sipariş oluştur (pending)
 */
exports.escrowLock = functions.region(region).https.onCall(async (data, context) => {
  return withSqlGateway(
    'escrowLock',
    () => escrowLockSql(data, context),
    () => escrowLockFirestore(data, context),
    context
  );
});

// ==================== ESCROW RELEASE ====================
/**
 * Siparişi tamamla - Parayı satıcıya transfer et
 * 
 * Input: { orderId: string }
 * Output: { ok: true } | { ok: false, error: string }
 * 
 * İşlem:
 * 1. Order ve escrow'u kontrol et
 * 2. Satıcının cüzdanına parayı ekle (komisyon düşülmüş)
 * 3. Komisyonu platform cüzdanına ekle
 * 4. Order'ı completed yap
 * 5. Escrow'u sil
 * 6. Ürünü sold yap
 */
exports.escrowRelease = functions.region(region).https.onCall(async (data, context) => {
  return withSqlGateway(
    'escrowRelease',
    () => escrowReleaseSql(data, context),
    () => escrowReleaseFirestore(data, context),
    context
  );
});

// ==================== ESCROW REFUND ====================
/**
 * Siparişi iptal et - Parayı alıcıya iade et
 * 
 * Input: { orderId: string }
 * Output: { ok: true } | { ok: false, error: string }
 * 
 * İşlem:
 * 1. Order ve escrow'u kontrol et
 * 2. Alıcının cüzdanına parayı iade et
 * 3. Order'ı canceled yap
 * 4. Escrow'u sil
 * 5. Ürünü tekrar active yap
 */
exports.escrowRefund = functions.region(region).https.onCall(async (data, context) => {
  return withSqlGateway(
    'escrowRefund',
    () => escrowRefundSql(data, context),
    () => escrowRefundFirestore(data, context),
    context
  );
});

// ==================== WALLET ADJUST ====================
exports.storeAdjustWallet = functions.region(region).https.onCall(async (data, context) => {
  return withSqlGateway(
    'storeAdjustWallet',
    () => walletAdjustSql(data, context),
    () => walletAdjustFirestore(data, context),
    context
  );
});

exports.storeListProducts = functions.region(region).https.onCall(async (data, context) => {
  const response = await executeStoreGatewayProcedure('storeListProducts', data, context);
  return {
    ok: true,
    ...response,
  };
});

exports.storeGetProduct = functions.region(region).https.onCall(async (data, context) => {
  const response = await executeStoreGatewayProcedure('storeGetProduct', data, context);
  return {
    ok: true,
    ...response,
  };
});

exports.storeGetWallet = functions.region(region).https.onCall(async (data, context) => {
  const response = await executeStoreGatewayProcedure('storeGetWallet', data, context);
  return {
    ok: true,
    ...response,
  };
});

exports.storeListOrdersForBuyer = functions.region(region).https.onCall(async (data, context) => {
  const response = await executeStoreGatewayProcedure('storeListOrdersForBuyer', data, context);
  return {
    ok: true,
    ...response,
  };
});

exports.storeShareProduct = functions.region(region).https.onCall(async (data, context) => {
  const response = await executeStoreGatewayProcedure('storeShareProduct', data, context);
  return {
    ok: true,
    ...response,
  };
});
