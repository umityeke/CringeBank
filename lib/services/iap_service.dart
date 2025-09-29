import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/iap_product.dart';
import '../services/user_service.dart';

enum IapPurchaseStatus { idle, pending, success, failure }

typedef CoinPackage = ({IapProduct product, ProductDetails details});

class IapPurchaseState {
  const IapPurchaseState({
    required this.status,
    this.productId,
    this.coinsAwarded,
    this.message,
  });

  final IapPurchaseStatus status;
  final String? productId;
  final int? coinsAwarded;
  final String? message;
}

class IapService {
  IapService._();

  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final StreamController<IapPurchaseState> _stateController = StreamController<IapPurchaseState>.broadcast();
  final Map<String, ProductDetails> _productDetailsById = {};
  final Map<String, IapProduct> _iapProductsBySku = {};
  bool _initialized = false;
  bool _isAvailable = false;

  Stream<IapPurchaseState> get purchaseStates => _stateController.stream;

  Future<bool> ensureInitialized() async {
    if (_initialized) {
      return _isAvailable;
    }

    _isAvailable = await _iap.isAvailable();
    _initialized = true;

    if (_isAvailable && _purchaseSubscription == null) {
      _purchaseSubscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (error) {
          _stateController.add(
            IapPurchaseState(
              status: IapPurchaseStatus.failure,
              message: error.toString(),
            ),
          );
        },
      );
    }

    if (!_isAvailable) {
      _stateController.add(
        const IapPurchaseState(
          status: IapPurchaseStatus.failure,
          message: 'Mağaza şu anda kullanılamıyor. Lütfen daha sonra tekrar dene.',
        ),
      );
    }

    return _isAvailable;
  }

  Future<List<CoinPackage>> loadActiveCoinPackages() async {
    final available = await ensureInitialized();
    if (!available) return const [];

    final snapshot = await _firestore
        .collection('iap_products')
        .where('isActive', isEqualTo: true)
        .orderBy('sort')
        .get();

    final platform = _currentPlatform();
  final products = snapshot.docs
        .map((doc) => IapProduct.fromMap(doc.data(), id: doc.id))
        .where((product) => _skuForPlatform(product, platform)?.isNotEmpty == true)
        .toList(growable: false);

    if (products.isEmpty) {
      return const [];
    }

  final skus = products
        .map((product) => _skuForPlatform(product, platform)!)
        .toSet();

    final response = await _iap.queryProductDetails(skus);
    for (final notFoundId in response.notFoundIDs) {
      debugPrint('⚠️ IAP SKU bulunamadı: $notFoundId');
    }

    _productDetailsById
      ..clear()
      ..addEntries(response.productDetails.map((details) => MapEntry(details.id, details)));
    _iapProductsBySku
      ..clear()
      ..addEntries(
        products
            .map((product) {
              final sku = _skuForPlatform(product, platform);
              if (sku == null) return null;
              return MapEntry(sku, product);
            })
            .whereType<MapEntry<String, IapProduct>>(),
      );

    final packages = <CoinPackage>[];
    for (final product in products) {
      final sku = _skuForPlatform(product, platform);
      if (sku == null) continue;
      final details = _productDetailsById[sku];
      if (details == null) continue;
      packages.add((product: product, details: details));
    }

    packages.sort((a, b) => a.product.sort.compareTo(b.product.sort));
    return packages;
  }

  Future<void> buyPackage(CoinPackage pack) async {
    final available = await ensureInitialized();
    if (!available) {
      _stateController.add(
        const IapPurchaseState(
          status: IapPurchaseStatus.failure,
          message: 'Satın alma için mağaza bağlantısı kurulamadı.',
        ),
      );
      return;
    }

    final details = pack.details;
    final purchaseParam = PurchaseParam(productDetails: details);
    _stateController.add(
      IapPurchaseState(
        status: IapPurchaseStatus.pending,
        productId: details.id,
      ),
    );

    await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _stateController.add(
            IapPurchaseState(
              status: IapPurchaseStatus.pending,
              productId: purchase.productID,
            ),
          );
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _verifyAndCredit(purchase);
          break;
        case PurchaseStatus.error:
          final message = purchase.error?.message ?? 'Satın alma tamamlanamadı.';
          _stateController.add(
            IapPurchaseState(
              status: IapPurchaseStatus.failure,
              productId: purchase.productID,
              message: message,
            ),
          );
          _completeIfPending(purchase);
          break;
        default:
          final statusName = purchase.status.toString().split('.').last;
          _stateController.add(
            IapPurchaseState(
              status: IapPurchaseStatus.failure,
              productId: purchase.productID,
              message: 'Satın alma durumu işlenemedi: $statusName.',
            ),
          );
          _completeIfPending(purchase);
          break;
      }
    }
  }

  Future<void> _verifyAndCredit(PurchaseDetails purchase) async {
    try {
      final user = UserService.instance.currentUser;
      final firebaseUser = UserService.instance.firebaseUser;
      final userId = user?.id ?? firebaseUser?.uid;
      if (userId == null || userId.isEmpty) {
        throw StateError('Kullanıcı oturumu bulunamadı.');
      }

      final platform = _currentPlatform();
      final productDetails = _productDetailsById[purchase.productID];
      final coinsAmount = productDetails != null
          ? _coinsAmountForSku(productDetails.id)
          : null;

      final result = await _functions.httpsCallable('verifyAndCreditIap').call({
        'platform': platform,
        'productId': _productIdForSku(purchase.productID) ?? purchase.productID,
        'storeSku': purchase.productID,
        'tokenOrReceipt': purchase.verificationData.serverVerificationData.trim(),
        'userId': userId,
        'transactionId': purchase.purchaseID,
        if (productDetails != null) 'price': productDetails.rawPrice,
        if (productDetails != null) 'currency': productDetails.currencyCode,
      });

      final data = result.data as Map<String, dynamic>?;
      final creditedCoins = data?['amountCoins'] as int? ?? coinsAmount;

      _stateController.add(
        IapPurchaseState(
          status: IapPurchaseStatus.success,
          productId: purchase.productID,
          coinsAwarded: creditedCoins,
        ),
      );

      await UserService.instance.loadUserData(userId);
    } catch (error) {
      _stateController.add(
        IapPurchaseState(
          status: IapPurchaseStatus.failure,
          productId: purchase.productID,
          message: error.toString(),
        ),
      );
    } finally {
      await _completeIfPending(purchase);
    }
  }

  Future<void> _completeIfPending(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  String _currentPlatform() {
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  String? _skuForPlatform(IapProduct product, String platform) {
    switch (platform) {
      case 'ios':
        return product.iosSku?.isNotEmpty == true ? product.iosSku : null;
      case 'android':
      default:
        return product.androidSku?.isNotEmpty == true ? product.androidSku : null;
    }
  }

  String? _productIdForSku(String sku) {
    return _iapProductsBySku[sku]?.id;
  }

  int? _coinsAmountForSku(String sku) {
    return _iapProductsBySku[sku]?.coinsAmount;
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    _stateController.close();
  }
}
