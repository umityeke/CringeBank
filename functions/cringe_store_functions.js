// ========================================
// CRINGESTORE CLOUD FUNCTIONS
// Full Security Escrow System
// Region: europe-west1
// ========================================

const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

// Region konfigürasyonu
const region = 'europe-west1';

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
  const db = admin.firestore();
  
  try {
    const buyerId = requireAuth(context);
    const { productId } = data;
    
    if (!productId) {
      throw new functions.https.HttpsError('invalid-argument', 'productId gerekli');
    }
    
    // Transaction ile atomik işlem
    const result = await db.runTransaction(async (transaction) => {
      // 1. Ürünü getir
      const productRef = db.collection('store_products').doc(productId);
      const productDoc = await transaction.get(productRef);
      
      if (!productDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Ürün bulunamadı');
      }
      
      const product = productDoc.data();
      
      if (product.status !== 'active') {
        throw new functions.https.HttpsError('failed-precondition', 'Ürün aktif değil');
      }
      
      // Kendi ürününü satın alamaz
      if (product.sellerId === buyerId) {
        throw new functions.https.HttpsError('failed-precondition', 'Kendi ürününüzü satın alamazsınız');
      }
      
      const priceGold = product.priceGold;
      const commissionGold = calculateCommission(priceGold);
      const totalCost = priceGold + commissionGold;
      
      // 2. Alıcının cüzdanını getir
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
      
      // 3. Order oluştur
      const orderRef = db.collection('store_orders').doc();
      const orderId = orderRef.id;
      const now = admin.firestore.FieldValue.serverTimestamp();
      
      const orderData = {
        orderId: orderId,
        productId: productId,
        buyerId: buyerId,
        sellerId: product.sellerId || product.vendorId,
        sellerType: product.sellerType,
        priceGold: priceGold,
        commissionGold: commissionGold,
        totalGold: totalCost,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      };
      
      transaction.set(orderRef, orderData);
      
      // 4. Escrow oluştur
      const escrowRef = db.collection('store_escrows').doc(orderId);
      const escrowData = {
        orderId: orderId,
        buyerId: buyerId,
        sellerId: product.sellerId || product.vendorId,
        amountGold: totalCost,
        status: 'locked',
        createdAt: now,
      };
      
      transaction.set(escrowRef, escrowData);
      
      // 5. Alıcının bakiyesinden düş
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
      
      // 6. Ürünü rezerve et
      transaction.update(productRef, {
        status: 'reserved',
        reservedBy: buyerId,
        reservedAt: now,
        updatedAt: now,
      });
      
      return orderId;
    });
    
    return { ok: true, orderId: result };
    
  } catch (error) {
    console.error('escrowLock error:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', error.message);
  }
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
  const db = admin.firestore();
  
  try {
    const userId = requireAuth(context);
    const { orderId } = data;
    
    if (!orderId) {
      throw new functions.https.HttpsError('invalid-argument', 'orderId gerekli');
    }
    
    await db.runTransaction(async (transaction) => {
      // 1. Order'ı getir
      const orderRef = db.collection('store_orders').doc(orderId);
      const orderDoc = await transaction.get(orderRef);
      
      if (!orderDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Sipariş bulunamadı');
      }
      
      const order = orderDoc.data();
      
      // Sadece alıcı veya admin release edebilir
      if (order.buyerId !== userId) {
        // TODO: Admin kontrolü ekle
        throw new functions.https.HttpsError('permission-denied', 'Bu işlemi yapmaya yetkiniz yok');
      }
      
      if (order.status !== 'pending') {
        throw new functions.https.HttpsError('failed-precondition', 'Sipariş pending durumunda değil');
      }
      
      // 2. Escrow'u getir
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
      
      // 3. Satıcının cüzdanına ekle
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
      
      // 4. Platform komisyonunu ekle (opsiyonel)
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
      
      // 5. Order'ı tamamla
      transaction.update(orderRef, {
        status: 'completed',
        completedAt: now,
        updatedAt: now,
      });
      
      // 6. Escrow'u sil
      transaction.update(escrowRef, {
        status: 'released',
        releasedAt: now,
      });
      
      // 7. Ürünü sold yap
      const productRef = db.collection('store_products').doc(order.productId);
      transaction.update(productRef, {
        status: 'sold',
        soldTo: order.buyerId,
        soldAt: now,
        updatedAt: now,
      });
    });
    
    return { ok: true };
    
  } catch (error) {
    console.error('escrowRelease error:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', error.message);
  }
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
  const db = admin.firestore();
  
  try {
    const userId = requireAuth(context);
    const { orderId } = data;
    
    if (!orderId) {
      throw new functions.https.HttpsError('invalid-argument', 'orderId gerekli');
    }
    
    await db.runTransaction(async (transaction) => {
      // 1. Order'ı getir
      const orderRef = db.collection('store_orders').doc(orderId);
      const orderDoc = await transaction.get(orderRef);
      
      if (!orderDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Sipariş bulunamadı');
      }
      
      const order = orderDoc.data();
      
      // Sadece satıcı, alıcı veya admin refund edebilir
      if (order.buyerId !== userId && order.sellerId !== userId) {
        // TODO: Admin kontrolü ekle
        throw new functions.https.HttpsError('permission-denied', 'Bu işlemi yapmaya yetkiniz yok');
      }
      
      if (order.status !== 'pending') {
        throw new functions.https.HttpsError('failed-precondition', 'Sipariş pending durumunda değil');
      }
      
      // 2. Escrow'u getir
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
      
      // 3. Alıcının cüzdanına iade et
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
      
      // 4. Order'ı iptal et
      transaction.update(orderRef, {
        status: 'canceled',
        canceledAt: now,
        canceledBy: userId,
        updatedAt: now,
      });
      
      // 5. Escrow'u refund yap
      transaction.update(escrowRef, {
        status: 'refunded',
        refundedAt: now,
      });
      
      // 6. Ürünü tekrar active yap
      const productRef = db.collection('store_products').doc(order.productId);
      transaction.update(productRef, {
        status: 'active',
        reservedBy: admin.firestore.FieldValue.delete(),
        reservedAt: admin.firestore.FieldValue.delete(),
        updatedAt: now,
      });
    });
    
    return { ok: true };
    
  } catch (error) {
    console.error('escrowRefund error:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', error.message);
  }
});
