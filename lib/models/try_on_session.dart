import 'package:cloud_firestore/cloud_firestore.dart';

enum TryOnSessionStatus { active, expired, cancelled }

typedef JsonMap = Map<String, dynamic>;

class TryOnSession {
  final String id;
  final String userId;
  final String itemId;
  final DateTime startedAt;
  final DateTime expiresAt;
  final TryOnSessionStatus status;
  final String source;

  const TryOnSession({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.startedAt,
    required this.expiresAt,
    this.status = TryOnSessionStatus.active,
    this.source = 'store',
  });

  bool get isActive => status == TryOnSessionStatus.active && !isExpired;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remaining =>
      isExpired ? Duration.zero : expiresAt.difference(DateTime.now());

  factory TryOnSession.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TryOnSession.fromMap(doc.id, doc.data() ?? const {});
  }

  factory TryOnSession.fromMap(String id, JsonMap data) {
    final started = _parseTimestamp(data['startedAt']) ?? DateTime.now();
    final expires = _parseTimestamp(data['expiresAt']) ??
        started.add(const Duration(seconds: 30));

    return TryOnSession(
      id: id,
      userId: data['userId'] as String? ?? '',
      itemId: data['itemId'] as String? ?? '',
      startedAt: started,
      expiresAt: expires,
      status: parseStatus(data['status'] as String?),
      source: data['source'] as String? ?? 'store',
    );
  }

  factory TryOnSession.fromCallablePayload(Map<String, dynamic> data) {
    final startedMillis = _readMillis(data['startedAtMillis']);
    final expiresMillis = _readMillis(data['expiresAtMillis']);
    final started = startedMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(startedMillis, isUtc: true).toLocal()
        : DateTime.now();
    final fallbackExpires = started.add(Duration(
      seconds: (data['durationSec'] as num?)?.toInt() ?? 30,
    ));
    final expires = expiresMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(expiresMillis, isUtc: true).toLocal()
        : fallbackExpires;

    return TryOnSession(
      id: data['id'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      itemId: data['itemId'] as String? ?? '',
      startedAt: started,
      expiresAt: expires,
      status: parseStatus(data['status'] as String?),
      source: data['source'] as String? ?? 'store',
    );
  }

  JsonMap toMap() {
    return {
      'userId': userId,
      'itemId': itemId,
      'startedAt': Timestamp.fromDate(startedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status.name.toUpperCase(),
      'source': source,
    };
  }

  TryOnSession copyWith({
    String? id,
    String? userId,
    String? itemId,
    DateTime? startedAt,
    DateTime? expiresAt,
    TryOnSessionStatus? status,
    String? source,
  }) {
    return TryOnSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemId: itemId ?? this.itemId,
      startedAt: startedAt ?? this.startedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      source: source ?? this.source,
    );
  }

  static TryOnSessionStatus parseStatus(String? value) {
    if (value == null) {
      return TryOnSessionStatus.active;
    }
    final normalized = value.toLowerCase();
    switch (normalized) {
      case 'expired':
        return TryOnSessionStatus.expired;
      case 'cancelled':
      case 'canceled':
        return TryOnSessionStatus.cancelled;
      default:
        return TryOnSessionStatus.active;
    }
  }

  static int? _readMillis(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
