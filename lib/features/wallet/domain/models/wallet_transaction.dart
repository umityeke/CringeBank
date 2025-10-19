class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.occurredAt,
    this.description,
  });

  final String id;
  final String title;
  final double amount;
  final DateTime occurredAt;
  final String? description;

  bool get isCredit => amount >= 0;
}
