// Report Model - User Reporting System
// Security Contract: Firestore path /reports/{reportId}

enum ReportReason {
  spam('spam', 'Spam/Reklam'),
  harassment('harassment', 'Taciz/Zorbalık'),
  hateSpeech('hate_speech', 'Nefret Söylemi'),
  violence('violence', 'Şiddet'),
  nudity('nudity', 'Müstehcenlik'),
  misinformation('misinformation', 'Yanlış Bilgi'),
  copyright('copyright', 'Telif Hakkı İhlali'),
  other('other', 'Diğer');

  final String value;
  final String displayName;

  const ReportReason(this.value, this.displayName);

  static ReportReason fromString(String value) {
    return ReportReason.values.firstWhere(
      (reason) => reason.value == value,
      orElse: () => ReportReason.other,
    );
  }
}

enum ReportTargetType {
  post('post', 'Gönderi'),
  comment('comment', 'Yorum'),
  user('user', 'Kullanıcı');

  final String value;
  final String displayName;

  const ReportTargetType(this.value, this.displayName);

  static ReportTargetType fromString(String value) {
    return ReportTargetType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ReportTargetType.post,
    );
  }
}

enum ReportStatus {
  pending('pending', 'Beklemede'),
  reviewed('reviewed', 'İncelendi'),
  resolved('resolved', 'Çözüldü'),
  dismissed('dismissed', 'Reddedildi');

  final String value;
  final String displayName;

  const ReportStatus(this.value, this.displayName);

  static ReportStatus fromString(String value) {
    return ReportStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ReportStatus.pending,
    );
  }
}

class ReportTarget {
  final ReportTargetType type;
  final String id;

  const ReportTarget({required this.type, required this.id});

  Map<String, dynamic> toJson() {
    return {'type': type.value, 'id': id};
  }

  factory ReportTarget.fromJson(Map<String, dynamic> json) {
    return ReportTarget(
      type: ReportTargetType.fromString(json['type'] ?? 'post'),
      id: json['id'] ?? '',
    );
  }
}

class Report {
  final String id;
  final String reporterId; // User who reported
  final ReportTarget target; // What was reported (post/comment/user)
  final ReportReason reason;
  final String? note; // Optional additional details
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy; // Moderator user ID
  final String? resolution; // Moderator notes

  const Report({
    required this.id,
    required this.reporterId,
    required this.target,
    required this.reason,
    this.note,
    this.status = ReportStatus.pending,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.resolution,
  });

  // === FIRESTORE SERIALIZATION ===

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporterId': reporterId,
      'target': target.toJson(),
      'reason': reason.value,
      'note': note,
      'status': status.value,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'reviewedAt': reviewedAt?.millisecondsSinceEpoch,
      'reviewedBy': reviewedBy,
      'resolution': resolution,
    };
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    // Parse createdAt - could be int milliseconds or string
    DateTime parsedCreatedAt;
    if (json['createdAt'] is int) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(json['createdAt']);
    } else if (json['createdAt'] is String) {
      parsedCreatedAt = DateTime.parse(json['createdAt']);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    // Parse reviewedAt similarly
    DateTime? parsedReviewedAt;
    if (json['reviewedAt'] != null) {
      if (json['reviewedAt'] is int) {
        parsedReviewedAt = DateTime.fromMillisecondsSinceEpoch(
          json['reviewedAt'],
        );
      } else if (json['reviewedAt'] is String) {
        parsedReviewedAt = DateTime.parse(json['reviewedAt']);
      }
    }

    return Report(
      id: json['id'] ?? '',
      reporterId: json['reporterId'] ?? '',
      target: ReportTarget.fromJson(json['target'] ?? {}),
      reason: ReportReason.fromString(json['reason'] ?? 'other'),
      note: json['note'],
      status: ReportStatus.fromString(json['status'] ?? 'pending'),
      createdAt: parsedCreatedAt,
      reviewedAt: parsedReviewedAt,
      reviewedBy: json['reviewedBy'],
      resolution: json['resolution'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'target': target.toJson(),
      'reason': reason.value,
      'note': note,
      'status': status.value,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'reviewedAt': reviewedAt?.millisecondsSinceEpoch,
      'reviewedBy': reviewedBy,
      'resolution': resolution,
    };
  }

  factory Report.fromFirestore(Map<String, dynamic> data, String docId) {
    // Parse timestamps
    DateTime parsedCreatedAt;
    if (data['createdAt'] != null) {
      final createdAtValue = data['createdAt'];
      if (createdAtValue is int) {
        parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
      } else {
        // Firestore Timestamp
        parsedCreatedAt = (createdAtValue as dynamic).toDate();
      }
    } else {
      parsedCreatedAt = DateTime.now();
    }

    DateTime? parsedReviewedAt;
    if (data['reviewedAt'] != null) {
      final reviewedAtValue = data['reviewedAt'];
      if (reviewedAtValue is int) {
        parsedReviewedAt = DateTime.fromMillisecondsSinceEpoch(reviewedAtValue);
      } else {
        parsedReviewedAt = (reviewedAtValue as dynamic).toDate();
      }
    }

    return Report(
      id: docId,
      reporterId: data['reporterId'] ?? '',
      target: ReportTarget.fromJson(data['target'] ?? {}),
      reason: ReportReason.fromString(data['reason'] ?? 'other'),
      note: data['note'],
      status: ReportStatus.fromString(data['status'] ?? 'pending'),
      createdAt: parsedCreatedAt,
      reviewedAt: parsedReviewedAt,
      reviewedBy: data['reviewedBy'],
      resolution: data['resolution'],
    );
  }

  // === UTILITY METHODS ===

  Report copyWith({
    String? id,
    String? reporterId,
    ReportTarget? target,
    ReportReason? reason,
    String? note,
    ReportStatus? status,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? resolution,
  }) {
    return Report(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      target: target ?? this.target,
      reason: reason ?? this.reason,
      note: note ?? this.note,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      resolution: resolution ?? this.resolution,
    );
  }

  bool get isPending => status == ReportStatus.pending;
  bool get isResolved => status == ReportStatus.resolved;
  bool get isDismissed => status == ReportStatus.dismissed;
}
