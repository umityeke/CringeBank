import 'package:cloud_firestore/cloud_firestore.dart';

/// Possible follow edge statuses stored in Firestore.
enum FollowEdgeStatus {
  pending,
  active,
  removed,
}

extension FollowEdgeStatusMapper on FollowEdgeStatus {
  String get asFirestoreValue {
    switch (this) {
      case FollowEdgeStatus.pending:
        return 'PENDING';
      case FollowEdgeStatus.active:
        return 'ACTIVE';
      case FollowEdgeStatus.removed:
        return 'REMOVED';
    }
  }

  bool get isActive => this == FollowEdgeStatus.active;
  bool get isPending => this == FollowEdgeStatus.pending;

  static FollowEdgeStatus fromFirestore(String? value) {
    switch (value?.toUpperCase()) {
      case 'ACTIVE':
        return FollowEdgeStatus.active;
      case 'PENDING':
        return FollowEdgeStatus.pending;
      case 'REMOVED':
      default:
        return FollowEdgeStatus.removed;
    }
  }
}

class FollowEdge {
  final String id;
  final String srcUid;
  final String dstUid;
  final FollowEdgeStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FollowEdge({
    required this.id,
    required this.srcUid,
    required this.dstUid,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  String get edgeKey => id.isNotEmpty ? id : '${srcUid}_$dstUid';

  bool get isPending => status.isPending;
  bool get isActive => status.isActive;

  FollowEdge copyWith({
    FollowEdgeStatus? status,
    DateTime? updatedAt,
  }) {
    return FollowEdge(
      id: id,
      srcUid: srcUid,
      dstUid: dstUid,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'srcUid': srcUid,
      'dstUid': dstUid,
      'status': status.asFirestoreValue,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory FollowEdge.fromMap(Map<String, dynamic> map, {String? id}) {
    final created = _parseTimestamp(map['createdAt']);
    final updated = _parseTimestamp(map['updatedAt']);

    return FollowEdge(
      id: id ?? map['id'] ?? '${map['srcUid']}_${map['dstUid']}',
      srcUid: (map['srcUid'] ?? '').toString(),
      dstUid: (map['dstUid'] ?? '').toString(),
      status: FollowEdgeStatusMapper.fromFirestore(map['status'] as String?),
      createdAt: created,
      updatedAt: updated,
    );
  }
}

class BlockEdge {
  final String id;
  final String srcUid;
  final String dstUid;
  final DateTime createdAt;

  const BlockEdge({
    required this.id,
    required this.srcUid,
    required this.dstUid,
    required this.createdAt,
  });

  String get edgeKey => id.isNotEmpty ? id : '${srcUid}_$dstUid';

  Map<String, dynamic> toMap() {
    return {
      'srcUid': srcUid,
      'dstUid': dstUid,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BlockEdge.fromMap(Map<String, dynamic> map, {String? id}) {
    return BlockEdge(
      id: id ?? map['id'] ?? '${map['srcUid']}_${map['dstUid']}',
      srcUid: (map['srcUid'] ?? '').toString(),
      dstUid: (map['dstUid'] ?? '').toString(),
      createdAt: _parseTimestamp(map['createdAt']),
    );
  }
}

/// Relationship states that the UI can render.
enum FollowRelationshipState {
  none,
  outgoingRequest,
  incomingRequest,
  following,
  blockedByMe,
  blockedByThem,
  blockedMutual,
  suspended,
}

class FollowRelationship {
  final FollowRelationshipState state;
  final FollowEdge? follow;
  final BlockEdge? outgoingBlock;
  final BlockEdge? incomingBlock;

  const FollowRelationship({
    required this.state,
    this.follow,
    this.outgoingBlock,
    this.incomingBlock,
  });

  bool get canFollow => state == FollowRelationshipState.none;
  bool get canCancelRequest => state == FollowRelationshipState.outgoingRequest;
  bool get canAcceptRequest => state == FollowRelationshipState.incomingRequest;
  bool get canUnfollow => state == FollowRelationshipState.following;
  bool get isBlocked => state == FollowRelationshipState.blockedByMe ||
      state == FollowRelationshipState.blockedByThem ||
      state == FollowRelationshipState.blockedMutual;

  FollowRelationship copyWith({
    FollowRelationshipState? state,
    FollowEdge? follow,
    BlockEdge? outgoingBlock,
    BlockEdge? incomingBlock,
  }) {
    return FollowRelationship(
      state: state ?? this.state,
      follow: follow ?? this.follow,
      outgoingBlock: outgoingBlock ?? this.outgoingBlock,
      incomingBlock: incomingBlock ?? this.incomingBlock,
    );
  }
}

DateTime _parseTimestamp(dynamic value) {
  if (value == null) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
