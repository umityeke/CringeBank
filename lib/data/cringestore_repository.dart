import 'dart:async';

import '../models/store_order.dart';
import '../models/store_product.dart';
import '../models/store_wallet.dart';
import '../models/user_model.dart' as user_model;
import '../services/cringe_store_service.dart';

/// Bridges the Flutter client with the SQL-backed Cloud Functions gateway.
/// Consumers should depend on this class instead of talking directly to
/// Firebase primitives, keeping the rest of the app agnostic to the data
/// source.
class CringeStoreRepository {
  static final CringeStoreRepository instance = CringeStoreRepository();

  CringeStoreRepository({CringeStoreService? storeService})
    : _storeService = storeService ?? CringeStoreService();

  final CringeStoreService _storeService;
  final Map<String, StoreProduct> _productCache = <String, StoreProduct>{};
  final Map<String, StreamController<StoreProduct?>> _productControllers =
      <String, StreamController<StoreProduct?>>{};

  /// Returns a cached stream of active products. The underlying service polls
  /// the SQL gateway on an interval and surfaces errors when the gateway is
  /// unreachable rather than silently falling back to Firestore.
  Stream<List<StoreProduct>> watchProducts({
    String filter = 'all',
    String? category,
  }) {
    return _storeService.getProducts(filter: filter, category: category).map((
      products,
    ) {
      for (final product in products) {
        _cacheProduct(product);
      }
      return products;
    });
  }

  /// Fetches single product details via the SQL gateway.
  Future<StoreProduct?> fetchProduct(String productId) async {
    final product = await _storeService.getProduct(productId);
    if (product != null) {
      _cacheProduct(product);
    } else {
      _notifyProductUnavailable(productId);
    }
    return product;
  }

  /// Emits a live-updating stream for a specific product id. The latest cached
  /// value is delivered immediately and the repository transparently refreshes
  /// from the SQL-backed service when missing.
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
    return _storeService.getWallet(userId);
  }

  Stream<StoreWallet?> watchCurrentWallet() {
    return _storeService.getCurrentWallet();
  }

  Stream<List<StoreOrder>> watchOrders(String userId) {
    return _storeService.getUserOrders(userId);
  }

  Stream<List<StoreOrder>> watchCurrentOrders() {
    return _storeService.getCurrentUserOrders();
  }

  Future<bool> isProductShared(String productId) async {
    final shared = await _storeService.isProductShared(productId);
    if (shared) {
      final cached = _productCache[productId];
      if (cached == null || !cached.isShared) {
        final refreshed = await fetchProduct(productId);
        if (refreshed != null) {
          _cacheProduct(refreshed);
        }
      }
    }
    return shared;
  }

  Future<StoreProductShareResult> shareSoldProduct({
    required StoreProduct product,
    required user_model.User seller,
  }) async {
    final result = await _storeService.shareSoldProduct(
      product: product,
      seller: seller,
    );
    final updatedProduct = result.product ?? await fetchProduct(product.id);
    if (updatedProduct != null) {
      _cacheProduct(updatedProduct);
    }
    return result;
  }

  /// Starts a new purchase flow through the SQL gateway Cloud Functions.
  Future<PurchaseResult> startPurchase({
    required String productId,
    required String? note,
  }) async {
    final result = await _storeService.lockEscrow(productId);
    final orderId = result['orderId']?.toString();
    if (result['ok'] == true && orderId != null && orderId.isNotEmpty) {
      return PurchaseResult.success(orderId: orderId);
    }
    return PurchaseResult.failure(result['error']?.toString() ?? 'unknown');
  }

  Future<void> confirmDelivery(String orderId) async {
    final result = await _storeService.releaseEscrow(orderId);
    if (result['ok'] != true) {
      throw StateError(result['error']?.toString() ?? 'release_failed');
    }
  }

  /// Refunds an order with optional reason (uses new SQL Gateway refund endpoint)
  Future<void> refundOrder(String orderId, {String? refundReason}) async {
    final result = await _storeService.refundOrder(
      orderId: orderId,
      refundReason: refundReason,
    );
    if (result['ok'] != true) {
      throw StateError(result['error']?.toString() ?? 'refund_failed');
    }
  }

  /// Fetches a single order by ID from SQL backend
  Future<StoreOrder?> fetchOrder(String orderId) async {
    return await _storeService.getOrder(orderId);
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
