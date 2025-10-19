import 'package:equatable/equatable.dart';

enum ProfileInsightTrend {
  up,
  down,
  stable,
}

class ProfileInsight extends Equatable {
  const ProfileInsight({
    required this.id,
    required this.label,
    required this.value,
    required this.changePercent,
    required this.trend,
  });

  final String id;
  final String label;
  final String value;
  final double changePercent;
  final ProfileInsightTrend trend;

  @override
  List<Object?> get props => [id, label, value, changePercent, trend];
}
