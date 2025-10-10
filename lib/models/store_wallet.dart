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
    this.ledgerEntries = const <StoreWalletLedgerEntry>[],
  });

  final String userId;
  final int goldBalance;
  final int pendingGold;
  final DateTime updatedAt;
  final String? lastLedgerEntryId;
  final List<StoreWalletLedgerEntry> ledgerEntries;

  int get availableGold => goldBalance - pendingGold;

  factory StoreWallet.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreWallet(
      userId: doc.id,
      goldBalance: data['goldBalance'] ?? data['balance'] ?? 0,
      pendingGold: data['pendingGold'] ?? data['pending'] ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLedgerEntryId: data['lastLedgerEntryId'] as String?,
      ledgerEntries: const <StoreWalletLedgerEntry>[],
    );
  }

  factory StoreWallet.fromGateway(
    Map<String, dynamic> payload, {
    List<dynamic>? ledger,
  }) {
    final ledgerEntries =
        (ledger ?? payload['ledger'])
            ?.whereType<Map<String, dynamic>>()
            .map(StoreWalletLedgerEntry.fromGateway)
            .toList() ??
        const <StoreWalletLedgerEntry>[];

    return StoreWallet(
      userId:
          payload['authUid']?.toString() ?? payload['userId']?.toString() ?? '',
      goldBalance: (payload['goldBalance'] ?? payload['balance'] ?? 0) is num
          ? (payload['goldBalance'] ?? payload['balance'] ?? 0).round()
          : int.tryParse(payload['goldBalance']?.toString() ?? '0') ?? 0,
      pendingGold: (payload['pendingGold'] ?? payload['pending'] ?? 0) is num
          ? (payload['pendingGold'] ?? payload['pending'] ?? 0).round()
          : int.tryParse(payload['pendingGold']?.toString() ?? '0') ?? 0,
      updatedAt: _parseDate(payload['updatedAt']),
      lastLedgerEntryId: payload['lastLedgerEntryId']?.toString(),
      ledgerEntries: ledgerEntries,
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

class StoreWalletLedgerEntry {
  const StoreWalletLedgerEntry({
    required this.ledgerId,
    required this.walletId,
    required this.amountDelta,
    required this.createdAt,
    this.targetAuthUid,
    this.actorAuthUid,
    this.reason,
    this.metadataJson,
  });

  final String ledgerId;
  final String walletId;
  final String? targetAuthUid;
  final String? actorAuthUid;
  final int amountDelta;
  final String? reason;
  final String? metadataJson;
  final DateTime createdAt;

  factory StoreWalletLedgerEntry.fromGateway(Map<String, dynamic> payload) {
    return StoreWalletLedgerEntry(
      ledgerId:
          payload['ledgerId']?.toString() ?? payload['id']?.toString() ?? '',
      walletId: payload['walletId']?.toString() ?? '',
      targetAuthUid: payload['targetAuthUid']?.toString(),
      actorAuthUid: payload['actorAuthUid']?.toString(),
      amountDelta: (payload['amountDelta'] ?? 0) is num
          ? (payload['amountDelta'] ?? 0).round()
          : int.tryParse(payload['amountDelta']?.toString() ?? '0') ?? 0,
      reason: payload['reason']?.toString(),
      metadataJson: payload['metadataJson']?.toString(),
      createdAt: _parseDate(payload['createdAt']),
    );
  }
}
