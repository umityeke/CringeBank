class WalletSummary {
  const WalletSummary({
    required this.availableBalance,
    required this.pendingBalance,
    required this.totalEarned,
    required this.updatedAt,
  });

  final double availableBalance;
  final double pendingBalance;
  final double totalEarned;
  final DateTime updatedAt;
}
