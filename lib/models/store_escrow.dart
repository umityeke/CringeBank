import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _parseDate(dynamic value) {
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

int _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

/// Escrow kaydı
/// - Alıcının altını kilitler
/// - Satıcı onayladığında release †’ komisyon kesilir, para satıcıya geçer
/// - İptal durumunda refund †’ para alıcıya iade
enum StoreEscrowStatus { held, released, refunded }

StoreEscrowStatus storeEscrowStatusFromRaw(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'RELEASED':
      return StoreEscrowStatus.released;
    case 'REFUNDED':
      return StoreEscrowStatus.refunded;
    case 'HELD':
    default:
      return StoreEscrowStatus.held;
  }
}

String storeEscrowStatusToRaw(StoreEscrowStatus status) {
  switch (status) {
    case StoreEscrowStatus.held:
      return 'HELD';
    case StoreEscrowStatus.released:
      return 'RELEASED';
    case StoreEscrowStatus.refunded:
      return 'REFUNDED';
  }
}

class StoreEscrow {
  const StoreEscrow({
    required this.id,
    required this.orderId,
    required this.buyerId,
    this.sellerId,
    this.vendorId,
    required this.lockedGold,
    this.releasedGold = 0,
    this.refundedGold = 0,
    required this.status,
    required this.createdAt,
    this.lockedAt,
    this.releasedAt,
    this.refundedAt,
  });

  final String id;
  final String orderId;
  final String buyerId;
  final String? sellerId;
  final String? vendorId;

  final int lockedGold;
  final int releasedGold;
  final int refundedGold;
  final StoreEscrowStatus status;

  final DateTime createdAt;
  final DateTime? lockedAt;
  final DateTime? releasedAt;
  final DateTime? refundedAt;

  bool get isHeld => status == StoreEscrowStatus.held;
  bool get isReleased => status == StoreEscrowStatus.released;
  bool get isRefunded => status == StoreEscrowStatus.refunded;

  static StoreEscrow? fromGateway(
    Map<String, dynamic>? payload, {
    required String orderId,
    required String buyerId,
    String? sellerId,
    String? vendorId,
  }) {
    if (payload == null) {
      return null;
    }

    final lockedAt = _parseDate(payload['lockedAt']);

    return StoreEscrow(
      id: payload['escrowId']?.toString() ?? 'escrow_$orderId',
      orderId: orderId,
      buyerId: buyerId,
      sellerId: sellerId ?? payload['sellerAuthUid']?.toString(),
      vendorId: vendorId ?? payload['vendorId']?.toString(),
      lockedGold: _parseInt(payload['lockedAmountGold']),
      releasedGold: _parseInt(payload['releasedAmountGold']),
      refundedGold: _parseInt(payload['refundedAmountGold']),
      status: storeEscrowStatusFromRaw(payload['state'] as String?),
      createdAt: lockedAt ?? DateTime.now(),
      lockedAt: lockedAt,
      releasedAt: _parseDate(payload['releasedAt']),
      refundedAt: _parseDate(payload['refundedAt']),
    );
  }

  factory StoreEscrow.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreEscrow(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      buyerId: data['buyerId'] ?? '',
      sellerId: data['sellerId'],
      vendorId: data['vendorId'],
      lockedGold: data['lockedGold'] ?? 0,
      releasedGold: data['releasedGold'] ?? 0,
      refundedGold: data['refundedGold'] ?? 0,
      status: storeEscrowStatusFromRaw(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lockedAt: (data['lockedAt'] as Timestamp?)?.toDate(),
      releasedAt: (data['releasedAt'] as Timestamp?)?.toDate(),
      refundedAt: (data['refundedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'vendorId': vendorId,
      'lockedGold': lockedGold,
      'releasedGold': releasedGold,
      'refundedGold': refundedGold,
      'status': storeEscrowStatusToRaw(status),
      'createdAt': Timestamp.fromDate(createdAt),
      if (lockedAt != null) 'lockedAt': Timestamp.fromDate(lockedAt!),
      'releasedAt': releasedAt != null ? Timestamp.fromDate(releasedAt!) : null,
      'refundedAt': refundedAt != null ? Timestamp.fromDate(refundedAt!) : null,
    };
  }
}
