import 'package:cloud_firestore/cloud_firestore.dart';

/// Sipariş durumu
/// - pending: Escrow'da bekliyor
/// - completed: Tamamlandı, para satıcıya geçti
/// - canceled: İptal edildi, para alıcıya iade
class StoreOrder {
  final String id;
  final String productId;
  final String buyerId;
  final String? sellerId;
  final String? vendorId;

  final int priceGold; // İşlem tutarı
  final int commissionGold; // Platform komisyonu

  final String status; // 'pending', 'completed', 'canceled'

  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? canceledAt;

  StoreOrder({
    required this.id,
    required this.productId,
    required this.buyerId,
    this.sellerId,
    this.vendorId,
    required this.priceGold,
    required this.commissionGold,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.canceledAt,
  });

  factory StoreOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreOrder(
      id: doc.id,
      productId: data['productId'] ?? '',
      buyerId: data['buyerId'] ?? '',
      sellerId: data['sellerId'],
      vendorId: data['vendorId'],
      priceGold: data['priceGold'] ?? 0,
      commissionGold: data['commissionGold'] ?? 0,
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      canceledAt: (data['canceledAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'vendorId': vendorId,
      'priceGold': priceGold,
      'commissionGold': commissionGold,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'canceledAt': canceledAt != null ? Timestamp.fromDate(canceledAt!) : null,
    };
  }
}
