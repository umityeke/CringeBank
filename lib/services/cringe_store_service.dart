import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../utils/platform_utils.dart';

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
  CollectionReference get _ordersCol => _firestore.collection('store_orders');
  CollectionReference get _walletsCol => _firestore.collection('store_wallets');
  CollectionReference get _escrowsCol => _firestore.collection('store_escrows');
  CollectionReference get _sharesCol =>
      _firestore.collection('store_product_shares');

  // ==================== PRODUCTS ====================

  /// Aktif ürünleri getir (filter: 'all', 'p2p', 'vendor')
  Stream<List<StoreProduct>> getProducts({
    String filter = 'all',
    String? category,
  }) {
    Query query = _productsCol.where('status', isEqualTo: 'active');

    // P2P: sellerId field exists and is not empty
    if (filter == 'p2p') {
      query = query.where('sellerType', isEqualTo: 'p2p');
    } else if (filter == 'vendor') {
      query = query.where('sellerType', isEqualTo: 'vendor');
    }

    if (category != null && category.isNotEmpty && category != 'all') {
      query = query.where('category', isEqualTo: category);
    }

    if (isWindowsDesktop) {
      final controller = StreamController<List<StoreProduct>>.broadcast();
      Timer? timer;
      List<StoreProduct>? last;
      final ordered = query.orderBy('createdAt', descending: true);
      Future<void> poll() async {
        try {
          final snapshot = await ordered.get();
          final list = snapshot.docs
              .map((d) => StoreProduct.fromFirestore(d))
              .toList();
          if (last == null ||
              list.length != last!.length ||
              !listEquals(list, last)) {
            last = list;
            if (!controller.isClosed) controller.add(list);
          }
        } catch (e) {
          if (!controller.isClosed) controller.add(last ?? const []);
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

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StoreProduct.fromFirestore(doc))
              .toList(),
        );
  }

  /// Tek ürün detayı
  Future<StoreProduct?> getProduct(String productId) async {
    final doc = await _productsCol.doc(productId).get();
    if (!doc.exists) return null;
    return StoreProduct.fromFirestore(doc);
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
    final doc = await _sharesCol.doc(productId.trim()).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>?;
    return (data?['shared'] as bool?) ?? false;
  }

  Future<StoreProductShareResult> shareSoldProduct({
    required StoreProduct product,
    required user_model.User seller,
  }) async {
    if (!product.isP2P || product.status != 'sold') {
      return const StoreProductShareResult(
        success: false,
        alreadyShared: false,
        message: 'Sadece satışı tamamlanmığ P2P ürünler paylaşılabilir.',
      );
    }

    final shareDoc = _sharesCol.doc(product.id);
    final existing = await shareDoc.get();
    if (existing.exists) {
      final data = existing.data() as Map<String, dynamic>?;
      final entryId = data?['entryId'] as String?;
      return StoreProductShareResult(
        success: false,
        alreadyShared: true,
        entryId: entryId,
        message: 'Bu ürün zaten paylaşılmığ.',
      );
    }

    final entryId = 'store_${product.id}';
    final displayName = _resolveUserName(seller);
    final handle = seller.username.trim().isNotEmpty
        ? '@${seller.username.trim()}'
        : '@${seller.id.substring(0, min(12, seller.id.length))}';
    final avatar = seller.avatar.trim().isNotEmpty
        ? seller.avatar.trim()
        : null;
    final descriptionBuffer = StringBuffer()
      ..writeln('${displayName.toUpperCase()} bir satığ gerçekleğtirdi!')
      ..writeln()
      ..writeln(
        product.desc.trim().isNotEmpty
            ? product.desc.trim()
            : '${product.title} satıldı.',
      )
      ..writeln()
      ..writeln('Fiyat: ${product.priceGold} Altın')
      ..writeln('Kategori: ${getCategoryDisplayName(product.category)}')
      ..writeln('#cringestore #satildi');

    final entry = CringeEntry(
      id: entryId,
      userId: seller.id,
      authorName: displayName,
      authorHandle: handle,
      baslik: 'Satıldı: ${product.title}',
      aciklama: descriptionBuffer.toString().trim(),
      kategori: CringeCategory.sosyalRezillik,
      krepSeviyesi: 5.5,
      createdAt: DateTime.now(),
      etiketler: const ['cringestore', 'satildi'],
      isAnonim: false,
      begeniSayisi: 0,
      yorumSayisi: 0,
      retweetSayisi: 0,
      imageUrls: product.images,
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
        message: 'ürün paylaşımı oluşturulamadı.',
      );
    }

    await shareDoc.set({
      'shared': true,
      'entryId': entryId,
      'sellerId': seller.id,
      'productId': product.id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _productsCol.doc(product.id).set({
      'sharedEntryId': entryId,
      'sharedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return StoreProductShareResult(
      success: true,
      alreadyShared: false,
      entryId: entryId,
      message: 'Satığ paylaşımı oluşturuldu.',
    );
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
    if (isWindowsDesktop) {
      final controller = StreamController<StoreWallet?>.broadcast();
      Timer? timer;
      StoreWallet? last;
      Future<void> poll() async {
        try {
          final doc = await _walletsCol.doc(userId).get();
          final next = doc.exists ? StoreWallet.fromFirestore(doc) : null;
          if ((last == null && next != null) ||
              (last != null && next == null) ||
              (last != null && next != null && last != next)) {
            last = next;
            if (!controller.isClosed) controller.add(next);
          }
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
    return _walletsCol.doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return StoreWallet.fromFirestore(doc);
    });
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
    final base = _ordersCol
        .where('buyerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);
    if (isWindowsDesktop) {
      final controller = StreamController<List<StoreOrder>>.broadcast();
      Timer? timer;
      List<StoreOrder>? last;
      Future<void> poll() async {
        try {
          final snapshot = await base.get();
          final list = snapshot.docs
              .map((d) => StoreOrder.fromFirestore(d))
              .toList();
          if (last == null || !listEquals(last, list)) {
            last = list;
            if (!controller.isClosed) controller.add(list);
          }
        } catch (e) {
          if (!controller.isClosed) controller.add(last ?? const []);
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
    return base.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => StoreOrder.fromFirestore(doc)).toList(),
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
      final callable = _functions.httpsCallable('escrowLock');
      final result = await callable.call({'productId': productId});
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Siparişi tamamla (para satıcıya geç)
  /// Cloud Function: escrowRelease({ orderId })
  /// Returns: { ok: true }
  Future<Map<String, dynamic>> releaseEscrow(String orderId) async {
    try {
      final callable = _functions.httpsCallable('escrowRelease');
      final result = await callable.call({'orderId': orderId});
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Siparişi iptal et (para alıcıya iade)
  /// Cloud Function: escrowRefund({ orderId })
  /// Returns: { ok: true }
  Future<Map<String, dynamic>> refundEscrow(String orderId) async {
    try {
      final callable = _functions.httpsCallable('escrowRefund');
      final result = await callable.call({'orderId': orderId});
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
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

  const StoreProductShareResult({
    required this.success,
    required this.alreadyShared,
    required this.message,
    this.entryId,
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
