import 'package:cloud_firestore/cloud_firestore.dart';

/// CringeStore ürün modeli
/// - P2P (kullanıcıdan kullanıcıya) veya Vendor satışı
/// - Kategori bazlı filtreleme
/// - Durum: active, reserved, sold, canceled
class StoreProduct {
  final String id;
  final String title;
  final String desc;
  final int priceGold; // Altın cinsinden fiyat
  final List<String> images; // Fotoğraf URL'leri
  final String category; // 'avatar', 'badge', 'theme', 'boost', vb.
  final String condition; // 'new', 'used'
  final String status; // 'active', 'reserved', 'sold', 'canceled'

  // P2P vs Vendor
  final String? sellerId; // P2P satıcı (kullanıcı)
  final String? vendorId; // Vendor (platform)
  final String? qrUid; // QR kodunun benzersiz kimliği
  final bool qrBound; // QR kodu fiziksel ürüne bağlanmış mı

  final DateTime createdAt;
  final DateTime updatedAt;

  StoreProduct({
    required this.id,
    required this.title,
    required this.desc,
    required this.priceGold,
    required this.images,
    required this.category,
    required this.condition,
    required this.status,
    this.sellerId,
    this.vendorId,
    required this.createdAt,
    required this.updatedAt,
    this.qrUid,
    this.qrBound = false,
  });

  factory StoreProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreProduct(
      id: doc.id,
      title: data['title'] ?? '',
      desc: data['desc'] ?? '',
      priceGold: data['priceGold'] ?? 0,
      images: List<String>.from(data['images'] ?? []),
      category: data['category'] ?? 'other',
      condition: data['condition'] ?? 'new',
      status: data['status'] ?? 'active',
      sellerId: data['sellerId'],
      vendorId: data['vendorId'],
      qrUid: data['qrUid'],
      qrBound: data['qrBound'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'desc': desc,
      'priceGold': priceGold,
      'images': images,
      'category': category,
      'condition': condition,
      'status': status,
      'sellerId': sellerId,
      'vendorId': vendorId,
      'sellerType': isP2P ? 'p2p' : 'vendor', // For efficient querying
      if (qrUid != null) 'qrUid': qrUid,
      'qrBound': qrBound,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  bool get isP2P => sellerId != null;
  bool get isVendor => vendorId != null;
  bool get isActive => status == 'active';
}
