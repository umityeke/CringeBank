import 'package:cloud_firestore/cloud_firestore.dart';

/// Escrow kaydı
/// - Alıcının altını kilitler
/// - Satıcı onayladığında release †’ komisyon kesilir, para satıcıya geçer
/// - İptal durumunda refund †’ para alıcıya iade
class StoreEscrow {
  final String id;
  final String orderId;
  final String buyerId;
  final String? sellerId;
  final String? vendorId;

  final int lockedGold; // Kilitli tutar
  final String status; // 'locked', 'released', 'refunded'

  final DateTime createdAt;
  final DateTime? releasedAt;
  final DateTime? refundedAt;

  StoreEscrow({
    required this.id,
    required this.orderId,
    required this.buyerId,
    this.sellerId,
    this.vendorId,
    required this.lockedGold,
    required this.status,
    required this.createdAt,
    this.releasedAt,
    this.refundedAt,
  });

  factory StoreEscrow.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreEscrow(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      buyerId: data['buyerId'] ?? '',
      sellerId: data['sellerId'],
      vendorId: data['vendorId'],
      lockedGold: data['lockedGold'] ?? 0,
      status: data['status'] ?? 'locked',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'releasedAt': releasedAt != null ? Timestamp.fromDate(releasedAt!) : null,
      'refundedAt': refundedAt != null ? Timestamp.fromDate(refundedAt!) : null,
    };
  }
}
