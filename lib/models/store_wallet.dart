import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcı cüzdanı
/// - Altın bakiyesi
/// - **YALNIZCA Cloud Functions tarafından güncellenebilir**
class StoreWallet {
  final String userId;
  final int goldBalance; // Mevcut altın bakiyesi
  final DateTime updatedAt;

  StoreWallet({
    required this.userId,
    required this.goldBalance,
    required this.updatedAt,
  });

  factory StoreWallet.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreWallet(
      userId: doc.id,
      goldBalance: data['goldBalance'] ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'goldBalance': goldBalance,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
