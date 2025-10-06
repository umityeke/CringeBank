import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcı cüzdanı
/// - Altın bakiyesi
/// - **YALNIZCA Cloud Functions tarafından güncellenebilir**
class StoreWallet {
  const StoreWallet({
    required this.userId,
    required this.goldBalance,
    required this.pendingGold,
    required this.updatedAt,
    this.lastLedgerEntryId,
  });

  final String userId;
  final int goldBalance;
  final int pendingGold;
  final DateTime updatedAt;
  final String? lastLedgerEntryId;

  int get availableGold => goldBalance - pendingGold;

  factory StoreWallet.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreWallet(
      userId: doc.id,
      goldBalance: data['goldBalance'] ?? data['balance'] ?? 0,
      pendingGold: data['pendingGold'] ?? data['pending'] ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLedgerEntryId: data['lastLedgerEntryId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'goldBalance': goldBalance,
      'balance': goldBalance,
      'pendingGold': pendingGold,
      'pending': pendingGold,
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (lastLedgerEntryId != null) 'lastLedgerEntryId': lastLedgerEntryId,
    };
  }
}
