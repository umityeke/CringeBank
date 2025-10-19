import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cringebank/core/di/service_locator.dart';
import 'package:cringebank/data/cringestore_repository.dart';
import 'package:cringebank/models/store_order.dart';
import 'package:cringebank/models/store_wallet.dart';

import '../../auth/application/auth_providers.dart';
import '../domain/models/wallet_summary.dart';
import '../domain/models/wallet_transaction.dart';

final walletStoreRepositoryProvider = Provider<CringeStoreRepository>((ref) {
  return sl<CringeStoreRepository>();
});

final walletSummaryProvider = StreamProvider<WalletSummary?>((ref) {
  final repository = ref.watch(walletStoreRepositoryProvider);
  ref.watch(currentUserProvider); // Yeniden abonelik için auth durumunu izliyoruz.

  return repository.watchCurrentWallet().map(_mapWalletToSummary);
});

final walletTransactionsProvider = StreamProvider<List<WalletTransaction>>((
  ref,
) {
  final repository = ref.watch(walletStoreRepositoryProvider);
  final currentUser = ref.watch(currentUserProvider);
  final userId = currentUser?.uid;

  if (userId == null || userId.isEmpty) {
  return Stream<List<WalletTransaction>>.value(<WalletTransaction>[]);
  }

  return repository.watchCurrentOrders().map((orders) {
    final transactions = orders
        .map((order) => _mapOrderToTransaction(order, viewerId: userId))
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return transactions;
  });
});

WalletSummary? _mapWalletToSummary(StoreWallet? wallet) {
  if (wallet == null) {
    return null;
  }

  return WalletSummary(
    availableBalance: wallet.availableGold.toDouble(),
    pendingBalance: wallet.pendingGold.toDouble(),
    totalEarned: wallet.goldBalance.toDouble(),
    updatedAt: wallet.updatedAt,
  );
}

WalletTransaction _mapOrderToTransaction(
  StoreOrder order, {
  required String viewerId,
}) {
  final isBuyer = order.buyerId == viewerId;
  final amount = (isBuyer ? -order.totalGold : order.totalGold).toDouble();
  final title = isBuyer ? 'Satın alma #${order.id}' : 'Satış geliri #${order.id}';
  final description = 'Durum: ${order.status.rawValue}';

  return WalletTransaction(
    id: order.id,
    title: title,
    amount: amount,
    occurredAt: order.updatedAt,
    description: description,
  );
}
