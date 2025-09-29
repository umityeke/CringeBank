import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletLedgerType { creditIap, debitPurchase, refund }

extension WalletLedgerTypeX on WalletLedgerType {
  String get asFirestoreValue {
    switch (this) {
      case WalletLedgerType.creditIap:
        return 'CREDIT_IAP';
      case WalletLedgerType.debitPurchase:
        return 'DEBIT_PURCHASE';
      case WalletLedgerType.refund:
        return 'REFUND';
    }
  }
}

WalletLedgerType walletLedgerTypeFromFirestore(String? raw) {
  switch (raw) {
    case 'CREDIT_IAP':
      return WalletLedgerType.creditIap;
    case 'DEBIT_PURCHASE':
      return WalletLedgerType.debitPurchase;
    case 'REFUND':
      return WalletLedgerType.refund;
    default:
      return WalletLedgerType.creditIap;
  }
}

class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.id,
    required this.userId,
    required this.type,
    required this.coinsDelta,
    required this.source,
    required this.createdAt,
    this.idempotencyKey,
  });

  final String id;
  final String userId;
  final WalletLedgerType type;
  final int coinsDelta;
  final String source;
  final DateTime createdAt;
  final String? idempotencyKey;

  factory WalletLedgerEntry.fromMap(Map<String, dynamic> map, {String? id}) {
    final resolvedId = (id ?? map['id'] ?? map['eventId'] ?? '').toString().trim();
    return WalletLedgerEntry(
      id: resolvedId,
      userId: map['userId']?.toString() ?? '',
      type: walletLedgerTypeFromFirestore(map['type']?.toString()),
      coinsDelta: _asInt(map['coinsDelta'] ?? map['delta']) ?? 0,
      source: map['source']?.toString() ?? '',
      createdAt: _asDate(map['createdAt']) ?? DateTime.now(),
      idempotencyKey: map['idempotencyKey']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.asFirestoreValue,
      'coinsDelta': coinsDelta,
      'source': source,
      'createdAt': Timestamp.fromDate(createdAt),
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
