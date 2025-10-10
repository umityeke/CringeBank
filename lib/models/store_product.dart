import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDate(dynamic value, {DateTime? fallback}) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toLocal();
    }
  }
  return fallback ?? DateTime.now();
}

DateTime? _parseNullableDate(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

List<String> _parseImages(dynamic value) {
  if (value == null) {
    return const <String>[];
  }
  if (value is List) {
    return value
        .where((element) => element != null)
        .map((element) => element.toString())
        .where((element) => element.isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    final trimmed = value.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        final decoded = List<dynamic>.from(
          (trimmed.isEmpty ? [] : (jsonDecode(trimmed) as List<dynamic>)),
        );
        return decoded
            .where((element) => element != null)
            .map((element) => element.toString())
            .where((element) => element.isNotEmpty)
            .toList();
      } catch (_) {
        return <String>[trimmed];
      }
    }
    return <String>[trimmed];
  }
  return const <String>[];
}

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
  final String sellerType; // p2p, vendor, community

  // P2P vs Vendor
  final String? sellerId; // P2P satıcı (kullanıcı)
  final String? vendorId; // Vendor (platform)
  final String? qrUid; // QR kodunun benzersiz kimliği
  final bool qrBound; // QR kodu fiziksel ürüne bağlanmış mı
  final String? reservedBy;
  final DateTime? reservedAt;
  final String? sharedEntryId;
  final String? sharedByAuthUid;
  final DateTime? sharedAt;

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
    required this.sellerType,
    this.sellerId,
    this.vendorId,
    required this.createdAt,
    required this.updatedAt,
    this.qrUid,
    this.qrBound = false,
    this.reservedBy,
    this.reservedAt,
    this.sharedEntryId,
    this.sharedByAuthUid,
    this.sharedAt,
  });

  factory StoreProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final sellerType =
        (data['sellerType'] as String?)?.toLowerCase() ??
        (data['sellerId'] != null ? 'p2p' : 'vendor');
    return StoreProduct(
      id: doc.id,
      title: data['title'] ?? '',
      desc: data['desc'] ?? '',
      priceGold: data['priceGold'] ?? 0,
      images: List<String>.from(data['images'] ?? []),
      category: data['category'] ?? 'other',
      condition: data['condition'] ?? 'new',
      status: data['status'] ?? 'active',
      sellerType: sellerType,
      sellerId: data['sellerId'],
      vendorId: data['vendorId'],
      qrUid: data['qrUid'],
      qrBound: data['qrBound'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reservedBy: data['reservedBy'] as String?,
      reservedAt: (data['reservedAt'] as Timestamp?)?.toDate(),
      sharedEntryId: data['sharedEntryId'] as String?,
      sharedByAuthUid: data['sharedByAuthUid'] as String?,
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory StoreProduct.fromGateway(Map<String, dynamic> payload) {
    return StoreProduct(
      id: payload['id']?.toString() ?? payload['productId']?.toString() ?? '',
      title: payload['title']?.toString() ?? '',
      desc:
          payload['desc']?.toString() ??
          payload['description']?.toString() ??
          '',
      priceGold: (payload['priceGold'] ?? payload['price_gold'] ?? 0) is num
          ? (payload['priceGold'] ?? payload['price_gold'] ?? 0).round()
          : int.tryParse(payload['priceGold']?.toString() ?? '0') ?? 0,
      images: _parseImages(payload['images'] ?? payload['imagesJson']),
      category: payload['category']?.toString() ?? 'other',
      condition: payload['condition']?.toString() ?? 'new',
      status: payload['status']?.toString().toLowerCase() ?? 'active',
      sellerType:
          payload['sellerType']?.toString().toLowerCase() ??
          (payload['sellerAuthUid'] != null ? 'p2p' : 'vendor'),
      sellerId:
          payload['sellerAuthUid']?.toString() ??
          payload['sellerId']?.toString(),
      vendorId: payload['vendorId']?.toString(),
      qrUid: payload['qrUid']?.toString(),
      qrBound: payload['qrBound'] == true,
      reservedBy: payload['reservedBy']?.toString(),
      reservedAt: _parseNullableDate(payload['reservedAt']),
      sharedEntryId:
          payload['sharedEntryId']?.toString() ??
          payload['shared_entry_id']?.toString(),
      sharedByAuthUid:
          payload['sharedByAuthUid']?.toString() ??
          payload['shared_by_auth_uid']?.toString(),
      sharedAt: _parseNullableDate(payload['sharedAt'] ?? payload['shared_at']),
      createdAt: _parseDate(payload['createdAt']),
      updatedAt: _parseDate(
        payload['updatedAt'],
        fallback: _parseDate(payload['createdAt']),
      ),
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
      'sellerType': sellerType,
      if (qrUid != null) 'qrUid': qrUid,
      'qrBound': qrBound,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (reservedBy != null) 'reservedBy': reservedBy,
      if (reservedAt != null) 'reservedAt': Timestamp.fromDate(reservedAt!),
      if (sharedEntryId != null) 'sharedEntryId': sharedEntryId,
      if (sharedByAuthUid != null) 'sharedByAuthUid': sharedByAuthUid,
      if (sharedAt != null) 'sharedAt': Timestamp.fromDate(sharedAt!),
    };
  }

  bool get isP2P => sellerType == 'p2p';
  bool get isVendor => sellerType == 'vendor';
  bool get isCommunity => sellerType == 'community';
  bool get isActive => status == 'active';
  bool get isShared => (sharedEntryId ?? '').isNotEmpty;

  StoreProduct copyWithShared({
    String? sharedEntryId,
    String? sharedByAuthUid,
    DateTime? sharedAt,
  }) {
    return StoreProduct(
      id: id,
      title: title,
      desc: desc,
      priceGold: priceGold,
      images: List<String>.from(images),
      category: category,
      condition: condition,
      status: status,
      sellerType: sellerType,
      sellerId: sellerId,
      vendorId: vendorId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      qrUid: qrUid,
      qrBound: qrBound,
      reservedBy: reservedBy,
      reservedAt: reservedAt,
      sharedEntryId: sharedEntryId ?? this.sharedEntryId,
      sharedByAuthUid: sharedByAuthUid ?? this.sharedByAuthUid,
      sharedAt: sharedAt ?? this.sharedAt,
    );
  }
}
