import 'package:cloud_firestore/cloud_firestore.dart';

enum StoreOrderStatus {
  created,
  held,
  released,
  refunded,
  disputed,
  cancelled;

  static StoreOrderStatus fromRaw(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'HELD':
        return StoreOrderStatus.held;
      case 'RELEASED':
        return StoreOrderStatus.released;
      case 'REFUNDED':
        return StoreOrderStatus.refunded;
      case 'DISPUTED':
        return StoreOrderStatus.disputed;
      case 'CANCELLED':
      case 'CANCELED':
        return StoreOrderStatus.cancelled;
      case 'CREATED':
      default:
        return StoreOrderStatus.created;
    }
  }

  String get rawValue {
    switch (this) {
      case StoreOrderStatus.created:
        return 'CREATED';
      case StoreOrderStatus.held:
        return 'HELD';
      case StoreOrderStatus.released:
        return 'RELEASED';
      case StoreOrderStatus.refunded:
        return 'REFUNDED';
      case StoreOrderStatus.disputed:
        return 'DISPUTED';
      case StoreOrderStatus.cancelled:
        return 'CANCELLED';
    }
  }
}

enum StoreOrderPaymentStatus { pending, paid, refunded, failed }

StoreOrderPaymentStatus paymentStatusFromRaw(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'PAID':
      return StoreOrderPaymentStatus.paid;
    case 'REFUNDED':
      return StoreOrderPaymentStatus.refunded;
    case 'FAILED':
      return StoreOrderPaymentStatus.failed;
    case 'PENDING':
    default:
      return StoreOrderPaymentStatus.pending;
  }
}

String paymentStatusToRaw(StoreOrderPaymentStatus status) {
  switch (status) {
    case StoreOrderPaymentStatus.pending:
      return 'PENDING';
    case StoreOrderPaymentStatus.paid:
      return 'PAID';
    case StoreOrderPaymentStatus.refunded:
      return 'REFUNDED';
    case StoreOrderPaymentStatus.failed:
      return 'FAILED';
  }
}

class StoreOrder {
  StoreOrder({
    required this.id,
    required this.productId,
    required this.buyerId,
    this.sellerId,
    this.vendorId,
    required this.itemPriceGold,
    required this.commissionGold,
    required this.totalGold,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
    this.deliveredAt,
    this.releasedAt,
    this.refundedAt,
    this.disputedAt,
    this.timeline,
  });

  final String id;
  final String productId;
  final String buyerId;
  final String? sellerId;
  final String? vendorId;

  final int itemPriceGold;
  final int commissionGold;
  final int totalGold;

  final StoreOrderStatus status;
  final StoreOrderPaymentStatus paymentStatus;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deliveredAt;
  final DateTime? releasedAt;
  final DateTime? refundedAt;
  final DateTime? disputedAt;
  final List<OrderTimelineEvent>? timeline;

  bool get isEscrowHeld => status == StoreOrderStatus.held;
  bool get isDisputed => status == StoreOrderStatus.disputed;
  bool get isCompleted => status == StoreOrderStatus.released;

  factory StoreOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timelineData = data['timeline'] as List<dynamic>?;
    return StoreOrder(
      id: doc.id,
      productId: data['productId'] ?? '',
      buyerId: data['buyerId'] ?? '',
      sellerId: data['sellerId'],
      vendorId: data['vendorId'],
      itemPriceGold: data['priceGold'] ?? data['itemPriceGold'] ?? 0,
      commissionGold: data['commissionGold'] ?? 0,
      totalGold:
          data['totalGold'] ??
          ((data['priceGold'] ?? 0) + (data['commissionGold'] ?? 0)),
      status: StoreOrderStatus.fromRaw(data['status'] as String?),
      paymentStatus: paymentStatusFromRaw(data['paymentStatus'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      releasedAt: (data['releasedAt'] as Timestamp?)?.toDate(),
      refundedAt: (data['refundedAt'] as Timestamp?)?.toDate(),
      disputedAt: (data['disputedAt'] as Timestamp?)?.toDate(),
      timeline: timelineData?.map((event) {
        return OrderTimelineEvent.fromMap(event as Map<String, dynamic>);
      }).toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'vendorId': vendorId,
      'priceGold': itemPriceGold,
      'itemPriceGold': itemPriceGold,
      'commissionGold': commissionGold,
      'totalGold': totalGold,
      'status': status.rawValue,
      'paymentStatus': paymentStatusToRaw(paymentStatus),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'deliveredAt': deliveredAt != null
          ? Timestamp.fromDate(deliveredAt!)
          : null,
      'releasedAt': releasedAt != null ? Timestamp.fromDate(releasedAt!) : null,
      'refundedAt': refundedAt != null ? Timestamp.fromDate(refundedAt!) : null,
      'disputedAt': disputedAt != null ? Timestamp.fromDate(disputedAt!) : null,
      if (timeline != null)
        'timeline': timeline!.map((event) => event.toMap()).toList(),
    };
  }
}

class OrderTimelineEvent {
  const OrderTimelineEvent({
    required this.status,
    required this.message,
    required this.createdAt,
  });

  final StoreOrderStatus status;
  final String message;
  final DateTime createdAt;

  factory OrderTimelineEvent.fromMap(Map<String, dynamic> map) {
    return OrderTimelineEvent(
      status: StoreOrderStatus.fromRaw(map['status'] as String?),
      message: map['message'] as String? ?? '',
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
                DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.rawValue,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
