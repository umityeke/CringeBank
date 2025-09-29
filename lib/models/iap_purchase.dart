import 'package:cloud_firestore/cloud_firestore.dart';

enum IapPlatform { android, ios }

enum IapPurchaseStatus { pending, success, failed, refunded }

extension IapPurchaseStatusX on IapPurchaseStatus {
  String get asFirestoreValue {
    switch (this) {
      case IapPurchaseStatus.pending:
        return 'PENDING';
      case IapPurchaseStatus.success:
        return 'SUCCESS';
      case IapPurchaseStatus.failed:
        return 'FAILED';
      case IapPurchaseStatus.refunded:
        return 'REFUNDED';
    }
  }

  bool get isFinal => this == IapPurchaseStatus.success || this == IapPurchaseStatus.failed || this == IapPurchaseStatus.refunded;
}

IapPurchaseStatus iapPurchaseStatusFromFirestore(String? raw) {
  switch (raw) {
    case 'SUCCESS':
      return IapPurchaseStatus.success;
    case 'FAILED':
      return IapPurchaseStatus.failed;
    case 'REFUNDED':
      return IapPurchaseStatus.refunded;
    case 'PENDING':
    default:
      return IapPurchaseStatus.pending;
  }
}

class IapPurchaseRecord {
  const IapPurchaseRecord({
    required this.id,
    required this.userId,
    required this.productId,
    required this.storeSku,
    required this.platform,
    required this.transactionId,
    required this.status,
    required this.amountCoins,
    this.price,
    this.currency,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String productId;
  final String storeSku;
  final IapPlatform platform;
  final String transactionId;
  final IapPurchaseStatus status;
  final int amountCoins;
  final double? price;
  final String? currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory IapPurchaseRecord.fromMap(Map<String, dynamic> map, {String? id}) {
    final resolvedId = (id ?? map['id'] ?? map['purchaseId'] ?? '').toString().trim();
    return IapPurchaseRecord(
      id: resolvedId,
      userId: map['userId']?.toString() ?? '',
      productId: map['productId']?.toString() ?? '',
      storeSku: map['storeSku']?.toString() ?? '',
      platform: _platformFrom(map['platform']),
      transactionId: (map['storeTransactionId'] ?? map['purchaseToken'] ?? map['transactionId'] ?? '').toString(),
      status: iapPurchaseStatusFromFirestore(map['status']?.toString()),
  amountCoins: _asInt(map['amountCoins'] ?? map['coinsAmount']) ?? 0,
      price: _asDouble(map['price']),
      currency: map['currency']?.toString(),
      createdAt: _asDate(map['createdAt']),
      updatedAt: _asDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'productId': productId,
      'storeSku': storeSku,
      'platform': platform.name,
      'storeTransactionId': transactionId,
      'status': status.asFirestoreValue,
      'amountCoins': amountCoins,
      if (price != null) 'price': price,
      if (currency != null) 'currency': currency,
  if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
  if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}

IapPlatform _platformFrom(dynamic value) {
  if (value is IapPlatform) return value;
  final normalized = value?.toString().toLowerCase();
  switch (normalized) {
    case 'ios':
      return IapPlatform.ios;
    case 'android':
    default:
      return IapPlatform.android;
  }
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value);
  }
  if (value is Timestamp) return value.toDate();
  return null;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}
