import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

enum TagApprovalStatus { pending, approved, rejected }

@immutable
class TagApprovalEntry extends Equatable {
  const TagApprovalEntry({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.requestedAt,
    this.flagReason,
    this.status = TagApprovalStatus.pending,
  });

  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final DateTime requestedAt;
  final String? flagReason;
  final TagApprovalStatus status;

  TagApprovalEntry copyWith({
    TagApprovalStatus? status,
  }) {
    return TagApprovalEntry(
      id: id,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      requestedAt: requestedAt,
      flagReason: flagReason,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        username,
        displayName,
        avatarUrl,
        requestedAt,
        flagReason,
        status,
      ];
}
