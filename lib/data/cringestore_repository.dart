import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/store_order.dart';
import '../models/store_product.dart';
import '../models/store_wallet.dart';
import '../services/cringe_store_service.dart';
import '../services/store_backend_api.dart';

/// Bridges the legacy Firestore-driven store service with the new
/// CringeStore REST backend. Consumers should depend on this class instead of
/// talking directly to Firebase or HTTP clients.
class CringeStoreRepository {
  static final CringeStoreRepository instance = CringeStoreRepository();

  CringeStoreRepository({
    CringeStoreService? firebaseService,
    StoreBackendApi? backendApi,
  }) : _firebaseService = firebaseService ?? CringeStoreService(),
       _backendApi = backendApi ?? StoreBackendApi.instance;

  final CringeStoreService _firebaseService;
  final StoreBackendApi _backendApi;
  final Map<String, StoreProduct> _productCache = <String, StoreProduct>{};
  final Map<String, StreamController<StoreProduct?>> _productControllers =
      <String, StreamController<StoreProduct?>>{};

  /// Returns a cached stream of active products. Until the REST backend starts
  /// exposing the catalogue endpoint we proxy to Firestore.
  Stream<List<StoreProduct>> watchProducts({
    String filter = 'all',
    String? category,
  }) {
    return _firebaseService.getProducts(filter: filter, category: category).map(
      (products) {
        for (final product in products) {
          _cacheProduct(product);
        }
        return products;
      },
    );
  }

  /// Fetches a single product details. Falls back to Firestore first because
  /// the catalogue API is not yet finalised.
  Future<StoreProduct?> fetchProduct(String productId) async {
    try {
      final dto = await _backendApi.fetchProduct(productId);
      if (dto != null) {
        final model = dto.toModel();
        _cacheProduct(model);
        return model;
      }
    } catch (e) {
      debugPrint('REST catalogue not reachable: $e');
    }
    final product = await _firebaseService.getProduct(productId);
    if (product != null) {
      _cacheProduct(product);
    } else {
      _notifyProductUnavailable(productId);
    }
    return product;
  }

  /// Emits a live-updating stream for a specific product id. The latest cached
  /// value is delivered immediately and the repository transparently refreshes
  /// from the REST backend when missing.
  Stream<StoreProduct?> watchProduct(String productId) {
    final controller = _productControllers.putIfAbsent(productId, () {
      final ctrl = StreamController<StoreProduct?>.broadcast();
      ctrl.onListen = () {
        final cached = _productCache[productId];
        if (cached != null) {
          ctrl.add(cached);
        } else {
          fetchProduct(productId).then((product) {
            if (product == null && !ctrl.isClosed) {
              ctrl.add(null);
            }
          });
        }
      };
      return ctrl;
    });

    return controller.stream;
  }

  Stream<StoreWallet?> watchWallet(String userId) {
    return _firebaseService.getWallet(userId);
  }

  Stream<StoreWallet?> watchCurrentWallet() {
    return _firebaseService.getCurrentWallet();
  }

  Stream<List<StoreOrder>> watchOrders(String userId) {
    return _firebaseService.getUserOrders(userId);
  }

  Stream<List<StoreOrder>> watchCurrentOrders() {
    return _firebaseService.getCurrentUserOrders();
  }

  /// Starts a new purchase flow. We prefer the REST API when available yet
  /// gracefully fallback to Cloud Functions.
  Future<PurchaseResult> startPurchase({
    required String productId,
    required String? note,
  }) async {
    try {
      final rest = await _backendApi.startEscrow(
        productId: productId,
        note: note,
      );
      return PurchaseResult.success(orderId: rest.orderId);
    } on BackendApiUnavailableException catch (_) {
      final legacy = await _firebaseService.lockEscrow(productId);
      if (legacy['ok'] == true) {
        return PurchaseResult.success(orderId: legacy['orderId'] as String);
      }
      return PurchaseResult.failure(legacy['error']?.toString() ?? 'unknown');
    }
  }

  Future<void> confirmDelivery(String orderId) async {
    try {
      await _backendApi.releaseEscrow(orderId: orderId);
    } on BackendApiUnavailableException catch (_) {
      await _firebaseService.releaseEscrow(orderId);
    }
  }

  Future<void> refundOrder(String orderId) async {
    try {
      await _backendApi.refundEscrow(orderId: orderId);
    } on BackendApiUnavailableException catch (_) {
      await _firebaseService.refundEscrow(orderId);
    }
  }

  void _cacheProduct(StoreProduct product) {
    _productCache[product.id] = product;
    final controller = _productControllers[product.id];
    if (controller != null && !controller.isClosed) {
      controller.add(product);
    }
  }

  void _notifyProductUnavailable(String productId) {
    _productCache.remove(productId);
    final controller = _productControllers[productId];
    if (controller != null && !controller.isClosed) {
      controller.add(null);
    }
  }
}

class PurchaseResult {
  const PurchaseResult._({required this.isSuccess, this.orderId, this.error});

  final bool isSuccess;
  final String? orderId;
  final String? error;

  factory PurchaseResult.success({required String orderId}) =>
      PurchaseResult._(isSuccess: true, orderId: orderId);

  factory PurchaseResult.failure(String error) =>
      PurchaseResult._(isSuccess: false, error: error);
}
