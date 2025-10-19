import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
class TagApprovalSettings extends Equatable {
  const TagApprovalSettings({
    required this.requireApproval,
  });

  final bool requireApproval;

  TagApprovalSettings copyWith({bool? requireApproval}) {
    return TagApprovalSettings(
      requireApproval: requireApproval ?? this.requireApproval,
    );
  }

  @override
  List<Object?> get props => [requireApproval];
}
