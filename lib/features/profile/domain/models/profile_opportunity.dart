import 'package:equatable/equatable.dart';

enum ProfileOpportunityStatus {
  open,
  closingSoon,
  waitlist,
}

class ProfileOpportunity extends Equatable {
  const ProfileOpportunity({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.deadline,
  });

  final String id;
  final String title;
  final String description;
  final ProfileOpportunityStatus status;
  final DateTime deadline;

  @override
  List<Object?> get props => [id, title, description, status, deadline];
}
