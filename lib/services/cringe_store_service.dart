import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../utils/platform_utils.dart';
import '../utils/store_feature_flags.dart';
import 'telemetry/callable_latency_tracker.dart';

import '../models/store_product.dart';
import '../models/store_order.dart';
import '../models/store_wallet.dart';
import '../models/store_escrow.dart';
import '../models/user_model.dart' as user_model;
import '../models/cringe_entry.dart';
import 'cringe_entry_service.dart';

class ProductImageUpload {
  ProductImageUpload({
    required this.bytes,
    required this.fileName,
    this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String? contentType;
}

/// CringeStore Marketplace servisi
/// - Firestore CRUD işlemleri
/// - Cloud Functions escrow sözleğmeleri
/// - P2P ve Vendor satığları
class CringeStoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Map<String, dynamic> _normalizeCallableResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      try {
        return Map<String, dynamic>.from(data);
      } catch (_) {
        return data.map((key, value) => MapEntry(key.toString(), value));
      }
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _callStoreFunction(
    String name, {
    Map<String, dynamic>? payload,
  }) async {
    final effectivePayload = payload ?? <String, dynamic>{};
    final result = await _functions.callWithLatency<dynamic>(
      name,
      payload: effectivePayload,
      category: 'cringeStore',
    );
    return _normalizeCallableResponse(result.data);
  }

  Stream<T> _createPollingStream<T>(
    Future<T> Function() fetch, {
    Duration interval = const Duration(seconds: 6),
    bool Function(T? previous, T next)? hasChanged,
  }) {
    late StreamController<T> controller;
    Timer? timer;
    int listenerCount = 0;
    bool hasValue = false;
    T? lastValue;

    Future<void> poll() async {
      try {
        final value = await fetch();
        final shouldEmit =
            hasChanged?.call(hasValue ? lastValue : null, value) ??
            (!hasValue || value != lastValue);
        lastValue = value;
        hasValue = true;
        if (shouldEmit && !controller.isClosed) {
          controller.add(value);
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    controller = StreamController<T>.broadcast(
      onListen: () {
        listenerCount++;
        if (listenerCount == 1) {
          poll();
          timer = Timer.periodic(interval, (_) => poll());
        }
      },
      onCancel: () {
        listenerCount--;
        if (listenerCount <= 0) {
          timer?.cancel();
          timer = null;
          hasValue = false;
          lastValue = null;
        }
      },
    );

    return controller.stream;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List<Map<String, dynamic>>) {
      return value;
    }
    if (value is List) {
      return value
          .whereType<Map>()
          .map((map) => Map<String, dynamic>.from(map))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  String? _mapFilterToSellerType(String filter) {
    switch (filter.trim().toLowerCase()) {
      case 'p2p':
        return 'P2P';
      case 'vendor':
      case 'platform':
        return 'VENDOR';
      case 'community':
        return 'COMMUNITY';
      default:
        return null;
    }
  }

  // Singleton pattern
  static final CringeStoreService _instance = CringeStoreService._internal();
  factory CringeStoreService() => _instance;
  CringeStoreService._internal();

  // ==================== CONSTANTS ====================

  static const double commissionRate = 0.05;

  /// Platform komisyonunu (altın cinsinden) hesaplar
  static int calculateCommission(int amountGold) {
    if (amountGold <= 0) {
      return 0;
    }
    return (amountGold * commissionRate).floor();
  }

  /// ürünün toplam maliyetini (fiyat + komisyon) döndürür
  static int calculateTotalCost(int amountGold) {
    return amountGold + calculateCommission(amountGold);
  }

  static String _resolveFileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < fileName.length - 1) {
      return '.${fileName.substring(dotIndex + 1).toLowerCase()}';
    }
    return '.jpg';
  }

  static String _inferContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg';
    }
  }

  // ==================== COLLECTIONS ====================

  CollectionReference get _productsCol =>
      _firestore.collection('store_products');
  CollectionReference get _escrowsCol => _firestore.collection('store_escrows');

  // ==================== PRODUCTS ====================

  /// Aktif ürünleri getir (filter: 'all', 'p2p', 'vendor')
  Stream<List<StoreProduct>> getProducts({
    String filter = 'all',
    String? category,
  }) {
    Future<List<StoreProduct>> fetchFromSql() async {
      final payload = <String, dynamic>{'status': 'ACTIVE', 'limit': 120};

      if (category != null && category.isNotEmpty && category != 'all') {
        payload['category'] = category;
      }

      final sellerType = _mapFilterToSellerType(filter);
      if (sellerType != null) {
        payload['sellerType'] = sellerType;
      }

      payload.removeWhere((key, value) => value == null);

      final response = await _callStoreFunction(
        'storeListProducts',
        payload: payload,
      );

      if (response['ok'] != true) {
        throw StateError(
          'storeListProducts failed: ${response['reason'] ?? response}',
        );
      }

      final products = _asMapList(
        response['products'],
      ).map((product) => StoreProduct.fromGateway(product)).toList();
      return products;
    }

    return _createPollingStream<List<StoreProduct>>(
      fetchFromSql,
      hasChanged: (previous, next) {
        if (previous == null) {
          return true;
        }
        if (previous.length != next.length) {
          return true;
        }
        for (var i = 0; i < previous.length; i++) {
          final prev = previous[i];
          final curr = next[i];
          if (prev.id != curr.id ||
              prev.status != curr.status ||
              prev.updatedAt != curr.updatedAt ||
              prev.priceGold != curr.priceGold) {
            return true;
          }
        }
        return false;
      },
    );
  }

  /// Tek ürün detayı
  Future<StoreProduct?> getProduct(String productId) async {
    final response = await _callStoreFunction(
      'storeGetProduct',
      payload: {'productId': productId},
    );
    if (response['ok'] == true && response['product'] != null) {
      return StoreProduct.fromGateway(
        Map<String, dynamic>.from(response['product']),
      );
    }
    return null;
  }

  /// ürün ekle (seller için)
  Future<String> createProduct(
    StoreProduct product, {
    List<ProductImageUpload> images = const [],
  }) async {
    final docRef = _productsCol.doc();
    final now = FieldValue.serverTimestamp();

    final List<String> imageUrls = <String>[];

    if (images.isNotEmpty) {
      final sellerKey = product.sellerId ?? product.vendorId ?? 'unknown';

      for (var i = 0; i < images.length; i++) {
        final upload = images[i];
        final extension = _resolveFileExtension(upload.fileName);
        final storagePath =
            'store_products/$sellerKey/${docRef.id}/image_${i + 1}$extension';

        final ref = _storage.ref(storagePath);
        final metadata = SettableMetadata(
          contentType: upload.contentType ?? _inferContentType(extension),
        );

        await ref.putData(upload.bytes, metadata);
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }
    }

    final mergedImages = <String>[
      ...imageUrls,
      ...product.images.where((url) => url.isNotEmpty),
    ];

    final data = Map<String, dynamic>.from(product.toFirestore())
      ..['images'] = mergedImages
      ..['createdAt'] = now
      ..['updatedAt'] = now;

    await docRef.set(data);
    return docRef.id;
  }

  // ==================== SHARE INTEGRATION ====================

  Future<bool> isProductShared(String productId) async {
    if (productId.trim().isEmpty) {
      return false;
    }
    final product = await getProduct(productId.trim());
    return product?.isShared ?? false;
  }

  Future<StoreProductShareResult> shareSoldProduct({
    required StoreProduct product,
    required user_model.User seller,
  }) async {
    final latestProduct = await getProduct(product.id) ?? product;

    if (!latestProduct.isP2P || latestProduct.status != 'sold') {
      return const StoreProductShareResult(
        success: false,
        alreadyShared: false,
        message: 'Sadece satışı tamamlanmış P2P ürünler paylaşılabilir.',
        reason: 'invalid_status',
      );
    }

    if (latestProduct.isShared) {
      return StoreProductShareResult(
        success: false,
        alreadyShared: true,
        entryId: latestProduct.sharedEntryId,
        message: 'Bu ürün zaten paylaşılmış.',
        product: latestProduct,
        reason: 'already_shared',
      );
    }

    final entryId = 'store_${latestProduct.id}';
    final displayName = _resolveUserName(seller);
    final handle = seller.username.trim().isNotEmpty
        ? '@${seller.username.trim()}'
        : '@${seller.id.substring(0, min(12, seller.id.length))}';
    final avatar = seller.avatar.trim().isNotEmpty
        ? seller.avatar.trim()
        : null;
    final descriptionBuffer = StringBuffer()
      ..writeln('${displayName.toUpperCase()} bir satış gerçekleştirdi!')
      ..writeln()
      ..writeln(
        latestProduct.desc.trim().isNotEmpty
            ? latestProduct.desc.trim()
            : '${latestProduct.title} satıldı.',
      )
      ..writeln()
      ..writeln('Fiyat: ${latestProduct.priceGold} Altın')
      ..writeln('Kategori: ${getCategoryDisplayName(latestProduct.category)}')
      ..writeln('#cringestore #satildi');

    final entry = CringeEntry(
      id: entryId,
      userId: seller.id,
      authorName: displayName,
      authorHandle: handle,
      baslik: 'Satıldı: ${latestProduct.title}',
      aciklama: descriptionBuffer.toString().trim(),
      kategori: CringeCategory.sosyalRezillik,
      krepSeviyesi: 5.5,
      createdAt: DateTime.now(),
      etiketler: const ['cringestore', 'satildi'],
      isAnonim: false,
      begeniSayisi: 0,
      yorumSayisi: 0,
      retweetSayisi: 0,
      imageUrls: latestProduct.images,
      audioUrl: null,
      videoUrl: null,
      borsaDegeri: null,
      authorAvatarUrl: avatar,
    );

    final entryCreated = await CringeEntryService.instance.addEntry(entry);
    if (!entryCreated) {
      return const StoreProductShareResult(
        success: false,
        alreadyShared: false,
        message: 'Ürün paylaşımı oluşturulamadı.',
        reason: 'entry_creation_failed',
      );
    }

    StoreProduct? updatedProduct;

    try {
      final response = await _callStoreFunction(
        'storeShareProduct',
        payload: {'productId': latestProduct.id, 'entryId': entryId},
      );

      final productPayload = response['product'];
      if (productPayload is Map) {
        updatedProduct = StoreProduct.fromGateway(
          Map<String, dynamic>.from(productPayload),
        );
      }

      await _productsCol.doc(latestProduct.id).set({
        'sharedEntryId': entryId,
        'sharedByAuthUid': seller.id,
        'sharedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      updatedProduct ??= await getProduct(latestProduct.id);
      updatedProduct ??= latestProduct.copyWithShared(
        sharedEntryId: entryId,
        sharedByAuthUid: seller.id,
        sharedAt: DateTime.now(),
      );

      return StoreProductShareResult(
        success: true,
        alreadyShared: false,
        entryId: entryId,
        message: 'Satış paylaşımı oluşturuldu.',
        product: updatedProduct,
        reason: 'shared_success',
      );
    } on FirebaseFunctionsException catch (error) {
      await _safeDeleteEntry(entryId);

      final normalizedReason = _normalizeGatewayReason(error);
      final alreadyShared =
          normalizedReason.endsWith('already_shared') ||
          normalizedReason.contains('already_shared') ||
          error.code == 'already-exists';

      if (alreadyShared) {
        updatedProduct = await getProduct(latestProduct.id) ?? latestProduct;
        return StoreProductShareResult(
          success: false,
          alreadyShared: true,
          entryId: updatedProduct.sharedEntryId,
          message: error.message ?? 'Bu ürün zaten paylaşılmış.',
          product: updatedProduct,
          reason: normalizedReason,
        );
      }

      return StoreProductShareResult(
        success: false,
        alreadyShared: false,
        message: error.message ?? 'Paylaşım sırasında hata oluştu.',
        reason: normalizedReason,
      );
    } catch (error) {
      await _safeDeleteEntry(entryId);
      return StoreProductShareResult(
        success: false,
        alreadyShared: false,
        message: 'Paylaşım sırasında hata oluştu: $error',
        reason: 'unexpected_failure',
      );
    }
  }

  Future<void> _safeDeleteEntry(String entryId) async {
    try {
      await CringeEntryService.instance.deleteEntry(entryId);
    } catch (_) {
      // Silme işlemi başarısız olsa da paylaşım akışını engellememesi için yutuyoruz.
    }
  }

  String _normalizeGatewayReason(FirebaseFunctionsException error) {
    final details = error.details;
    if (details is Map && details['reason'] != null) {
      return details['reason'].toString().trim().toLowerCase();
    }
    if (error.message != null && error.message!.trim().isNotEmpty) {
      final message = error.message!.trim().toLowerCase();
      if (message.startsWith('sp_store_recordproductshare failed')) {
        return 'sql_gateway_share_update_failed';
      }
      return message;
    }
    return error.code.trim().toLowerCase();
  }

  String _resolveUserName(user_model.User user) {
    if (user.displayName.trim().isNotEmpty) return user.displayName.trim();
    if (user.fullName.trim().isNotEmpty) return user.fullName.trim();
    if (user.username.trim().isNotEmpty) return user.username.trim();
    return user.id;
  }

  // ==================== WALLET ====================

  /// Kullanıcı cüzdanını dinle
  Stream<StoreWallet?> getWallet(String userId) {
    Future<StoreWallet?> fetchFromSql() async {
      final response = await _callStoreFunction(
        'storeGetWallet',
        payload: {'targetAuthUid': userId, 'createIfMissing': true},
      );

      if (response['ok'] != true) {
        throw StateError(
          'storeGetWallet failed: ${response['reason'] ?? response}',
        );
      }

      final walletData = response['wallet'];
      if (walletData == null) {
        return null;
      }

      return StoreWallet.fromGateway(
        Map<String, dynamic>.from(walletData),
        ledger: _asMapList(response['ledger']),
      );
    }

    return _createPollingStream<StoreWallet?>(
      fetchFromSql,
      hasChanged: (StoreWallet? previous, StoreWallet? next) {
        if (previous == null && next == null) {
          return false;
        }
        if (previous == null || next == null) {
          return true;
        }
        return previous.goldBalance != next.goldBalance ||
            previous.pendingGold != next.pendingGold ||
            previous.updatedAt != next.updatedAt;
      },
    );
  }

  /// Mevcut kullanıcı cüzdanı
  Stream<StoreWallet?> getCurrentWallet() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    return getWallet(user.uid);
  }

  // ==================== ORDERS ====================

  /// Kullanıcının siparişlerini getir
  Stream<List<StoreOrder>> getUserOrders(String userId) {
    Future<List<StoreOrder>> fetchFromSql() async {
      final response = await _callStoreFunction(
        'storeListOrdersForBuyer',
        payload: {'buyerAuthUid': userId, 'limit': 100},
      );

      if (response['ok'] != true) {
        throw StateError(
          'storeListOrdersForBuyer failed: ${response['reason'] ?? response}',
        );
      }

      return _asMapList(
        response['orders'],
      ).map(StoreOrder.fromGateway).toList();
    }

    return _createPollingStream<List<StoreOrder>>(
      fetchFromSql,
      hasChanged: (List<StoreOrder>? previous, List<StoreOrder> next) {
        if (previous == null) {
          return true;
        }
        if (previous.length != next.length) {
          return true;
        }
        for (int i = 0; i < previous.length; i++) {
          final a = previous[i];
          final b = next[i];
          if (a.id != b.id ||
              a.status != b.status ||
              a.updatedAt != b.updatedAt) {
            return true;
          }
        }
        return false;
      },
    );
  }

  /// Mevcut kullanıcının siparişleri
  Stream<List<StoreOrder>> getCurrentUserOrders() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return getUserOrders(user.uid);
  }

  // ==================== ESCROW FUNCTIONS ====================

  /// Satın alma işlemi başlat (escrow lock)
  /// Cloud Function: escrowLock({ productId })
  /// Returns: { ok: true, orderId: '...' }
  Future<Map<String, dynamic>> lockEscrow(String productId) async {
    try {
      if (StoreFeatureFlags.useSqlEscrowGateway) {
        final result = await _functions.callWithLatency<dynamic>(
          'sqlGatewayStoreCreateOrder',
          payload: {'productId': productId},
          category: 'cringeStore',
        );
        final data = _normalizeCallableResponse(result.data);
        final fallbackOrderId = data['orderPublicId'] ?? data['OrderPublicId'];
        final rawOrderId = data['orderId'] ?? fallbackOrderId;
        final orderId = rawOrderId is String
            ? rawOrderId.trim()
            : rawOrderId != null
            ? rawOrderId.toString().trim()
            : '';

        data['source'] = 'sqlGateway';
        if (orderId.isNotEmpty) {
          data['ok'] = true;
          data['orderId'] = orderId;
          return data;
        }

        return {
          'ok': data['ok'] == true,
          'orderId': orderId.isNotEmpty ? orderId : null,
          'error': data['error']?.toString() ?? 'order_id_missing',
          'source': 'sqlGateway',
        };
      }

      final result = await _functions.callWithLatency<dynamic>(
        'escrowLock',
        payload: {'productId': productId},
        category: 'cringeStore',
      );
      final data = _normalizeCallableResponse(result.data)
        ..putIfAbsent('source', () => 'legacy');
      if (!data.containsKey('ok')) data['ok'] = true;
      return data;
    } catch (e) {
      return {
        'ok': false,
        'error': e.toString(),
        'source': StoreFeatureFlags.useSqlEscrowGateway
            ? 'sqlGateway'
            : 'legacy',
      };
    }
  }

  /// Siparişi tamamla (para satıcıya geç)
  /// Cloud Function: escrowRelease({ orderId })
  /// Returns: { ok: true }
  Future<Map<String, dynamic>> releaseEscrow(String orderId) async {
    try {
      if (StoreFeatureFlags.useSqlEscrowGateway) {
        final result = await _functions.callWithLatency<dynamic>(
          'sqlGatewayStoreReleaseEscrow',
          payload: {'orderId': orderId},
          category: 'cringeStore',
        );
        final data = _normalizeCallableResponse(result.data);
        final rawOrderId =
            data['orderId'] ?? data['orderPublicId'] ?? data['OrderPublicId'];
        final resolvedOrderId = rawOrderId is String
            ? rawOrderId.trim()
            : rawOrderId != null
            ? rawOrderId.toString().trim()
            : orderId;
        return {
          'ok': data['ok'] == false ? false : true,
          'orderId': resolvedOrderId.isNotEmpty ? resolvedOrderId : orderId,
          'status': data['status'] ?? 'released',
          if (data.containsKey('returnValue'))
            'returnValue': data['returnValue'],
          'source': 'sqlGateway',
        };
      }

      final result = await _functions.callWithLatency<dynamic>(
        'escrowRelease',
        payload: {'orderId': orderId},
        category: 'cringeStore',
      );
      final data = _normalizeCallableResponse(result.data)
        ..putIfAbsent('source', () => 'legacy')
        ..putIfAbsent('ok', () => true)
        ..putIfAbsent('orderId', () => orderId);
      return data;
    } catch (e) {
      return {
        'ok': false,
        'error': e.toString(),
        'orderId': orderId,
        'source': StoreFeatureFlags.useSqlEscrowGateway
            ? 'sqlGateway'
            : 'legacy',
      };
    }
  }

  /// Siparişi iptal et (para alıcıya iade) - Legacy escrow refund
  /// Cloud Function: escrowRefund({ orderId })
  /// Returns: { ok: true }
  /// @deprecated Use refundOrder instead for new implementations
  Future<Map<String, dynamic>> refundEscrow(String orderId) async {
    try {
      if (StoreFeatureFlags.useSqlEscrowGateway) {
        final result = await _functions.callWithLatency<dynamic>(
          'sqlGatewayStoreRefundEscrow',
          payload: {'orderId': orderId},
          category: 'cringeStore',
        );
        final data = _normalizeCallableResponse(result.data);
        final rawOrderId =
            data['orderId'] ?? data['orderPublicId'] ?? data['OrderPublicId'];
        final resolvedOrderId = rawOrderId is String
            ? rawOrderId.trim()
            : rawOrderId != null
            ? rawOrderId.toString().trim()
            : orderId;
        return {
          'ok': data['ok'] == false ? false : true,
          'orderId': resolvedOrderId.isNotEmpty ? resolvedOrderId : orderId,
          'status': data['status'] ?? 'refunded',
          if (data.containsKey('returnValue'))
            'returnValue': data['returnValue'],
          'source': 'sqlGateway',
        };
      }

      final result = await _functions.callWithLatency<dynamic>(
        'escrowRefund',
        payload: {'orderId': orderId},
        category: 'cringeStore',
      );
      final data = _normalizeCallableResponse(result.data)
        ..putIfAbsent('source', () => 'legacy')
        ..putIfAbsent('ok', () => true)
        ..putIfAbsent('orderId', () => orderId);
      return data;
    } catch (e) {
      return {
        'ok': false,
        'error': e.toString(),
        'orderId': orderId,
        'source': StoreFeatureFlags.useSqlEscrowGateway
            ? 'sqlGateway'
            : 'legacy',
      };
    }
  }

  /// Siparişi iptal et ve iade işlemini başlat (Enhanced refund with full order lifecycle)
  /// Cloud Function: sqlGatewayStoreRefundOrder({ orderId, refundReason })
  /// Returns: { ok: true, orderId, refundId, status: 'refunded' }
  Future<Map<String, dynamic>> refundOrder({
    required String orderId,
    String? refundReason,
  }) async {
    try {
      if (StoreFeatureFlags.useSqlEscrowGateway) {
        final result = await _functions.callWithLatency<dynamic>(
          'sqlGatewayStoreRefundOrder',
          payload: {
            'orderId': orderId,
            if (refundReason != null && refundReason.isNotEmpty)
              'refundReason': refundReason,
          },
          category: 'cringeStore',
        );
        final data = _normalizeCallableResponse(result.data);
        final rawOrderId =
            data['orderId'] ?? data['orderPublicId'] ?? data['OrderPublicId'];
        final resolvedOrderId = rawOrderId is String
            ? rawOrderId.trim()
            : rawOrderId != null
            ? rawOrderId.toString().trim()
            : orderId;
        final rawRefundId =
            data['refundId'] ??
            data['refundPublicId'] ??
            data['RefundPublicId'];
        final refundId = rawRefundId is String
            ? rawRefundId.trim()
            : rawRefundId?.toString().trim();
        return {
          'ok': data['ok'] == false ? false : true,
          'orderId': resolvedOrderId.isNotEmpty ? resolvedOrderId : orderId,
          'refundId': refundId,
          'status': data['status'] ?? 'refunded',
          if (data.containsKey('returnValue'))
            'returnValue': data['returnValue'],
          'source': 'sqlGateway',
        };
      }

      // Fallback to legacy refundEscrow if SQL Gateway disabled
      return await refundEscrow(orderId);
    } catch (e) {
      return {
        'ok': false,
        'error': e.toString(),
        'orderId': orderId,
        'source': StoreFeatureFlags.useSqlEscrowGateway
            ? 'sqlGateway'
            : 'legacy',
      };
    }
  }

  /// Tek sipariş detayını getir
  /// Cloud Function: sqlGatewayStoreGetOrder({ orderId })
  /// Returns: { order: StoreOrder? }
  Future<StoreOrder?> getOrder(String orderId) async {
    if (orderId.trim().isEmpty) {
      return null;
    }

    try {
      if (StoreFeatureFlags.useSqlEscrowGateway) {
        final result = await _functions.callWithLatency<dynamic>(
          'sqlGatewayStoreGetOrder',
          payload: {'orderId': orderId.trim()},
          category: 'cringeStore',
        );
        final data = _normalizeCallableResponse(result.data);

        if (data['ok'] == false) {
          return null;
        }

        final orderData = data['order'];
        if (orderData == null) {
          return null;
        }

        return StoreOrder.fromGateway(Map<String, dynamic>.from(orderData));
      }

      // Fallback: search in Firestore (legacy)
      final ordersSnapshot = await _firestore
          .collection('store_orders')
          .where('id', isEqualTo: orderId)
          .limit(1)
          .get();

      if (ordersSnapshot.docs.isEmpty) {
        return null;
      }

      return StoreOrder.fromFirestore(ordersSnapshot.docs.first);
    } catch (e) {
      // Log error silently, return null
      return null;
    }
  }

  // ==================== ESCROW MONITORING ====================

  /// Sipariş escrow durumunu dinle
  Stream<StoreEscrow?> getEscrow(String orderId) {
    final base = _escrowsCol.where('orderId', isEqualTo: orderId).limit(1);
    if (isWindowsDesktop) {
      final controller = StreamController<StoreEscrow?>.broadcast();
      Timer? timer;
      StoreEscrow? last;
      Future<void> poll() async {
        try {
          final snapshot = await base.get();
          final next = snapshot.docs.isEmpty
              ? null
              : StoreEscrow.fromFirestore(snapshot.docs.first);
          // We don't have == override; always emit if changed by identity
          if (!controller.isClosed) controller.add(next);
          last = next;
        } catch (e) {
          if (!controller.isClosed) controller.add(last);
        }
      }

      controller
        ..onListen = () {
          poll();
          timer = Timer.periodic(const Duration(seconds: 8), (_) => poll());
        }
        ..onCancel = () async {
          timer?.cancel();
        };
      return controller.stream;
    }
    return base.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return StoreEscrow.fromFirestore(snapshot.docs.first);
    });
  }

  // ==================== KATEGORILER ====================

  /// Store kategorileri (ana kategori + alt kategori)
  static const List<StoreCategoryGroup> categoryGroups = [
    StoreCategoryGroup(
      id: 'elektronik',
      title: 'Elektronik',
      subCategories: [
        StoreSubCategory(id: 'telefon-tablet', title: 'Telefon & Tablet'),
        StoreSubCategory(id: 'bilgisayar-laptop', title: 'Bilgisayar & Laptop'),
        StoreSubCategory(id: 'tv-ses', title: 'TV & Ses Sistemleri'),
        StoreSubCategory(id: 'konsol-oyun', title: 'Konsol & Oyunlar'),
        StoreSubCategory(id: 'aksesuar', title: 'Aksesuarlar'),
      ],
    ),
    StoreCategoryGroup(
      id: 'ev-yasam',
      title: 'Ev & Yağam',
      subCategories: [
        StoreSubCategory(id: 'dekorasyon', title: 'Ev Dekorasyonu'),
        StoreSubCategory(id: 'beyaz-esya', title: 'Beyaz Eğya'),
        StoreSubCategory(id: 'kucuk-ev-aletleri', title: 'Küçük Ev Aletleri'),
      ],
    ),
    StoreCategoryGroup(
      id: 'kitap-hobi',
      title: 'Kitap & Hobi',
      subCategories: [
        StoreSubCategory(id: 'kitap-dergi', title: 'Kitap & Dergi'),
      ],
    ),
    StoreCategoryGroup(
      id: 'diger',
      title: 'Diğer',
      subCategories: [StoreSubCategory(id: 'diger', title: 'Diğer')],
    ),
  ];

  /// Tüm alt kategori kimlikleri (Firestore query'leri için)
  static List<String> get categories => categoryGroups
      .expand((group) => group.subCategories.map((sub) => sub.id))
      .toList(growable: false);

  static StoreCategoryGroup? getCategoryGroup(String groupId) {
    for (final group in categoryGroups) {
      if (group.id == groupId) {
        return group;
      }
    }
    return null;
  }

  static StoreSubCategory? getSubCategory(String subId) {
    for (final group in categoryGroups) {
      for (final sub in group.subCategories) {
        if (sub.id == subId) {
          return sub;
        }
      }
    }
    return null;
  }

  static StoreCategoryGroup? getGroupForSub(String subId) {
    for (final group in categoryGroups) {
      if (group.subCategories.any((sub) => sub.id == subId)) {
        return group;
      }
    }
    return null;
  }

  static String getCategoryDisplayName(String category) {
    final sub = getSubCategory(category);
    if (sub != null) {
      return sub.title;
    }
    final group = getCategoryGroup(category);
    if (group != null) {
      return group.title;
    }
    return 'Diğer';
  }
}

class StoreProductShareResult {
  final bool success;
  final bool alreadyShared;
  final String message;
  final String? entryId;
  final StoreProduct? product;
  final String? reason;

  const StoreProductShareResult({
    required this.success,
    required this.alreadyShared,
    required this.message,
    this.entryId,
    this.product,
    this.reason,
  });
}

class StoreCategoryGroup {
  const StoreCategoryGroup({
    required this.id,
    required this.title,
    required this.subCategories,
  });

  final String id;
  final String title;
  final List<StoreSubCategory> subCategories;
}

class StoreSubCategory {
  const StoreSubCategory({required this.id, required this.title});

  final String id;
  final String title;
}
