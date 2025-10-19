import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/wallet_providers.dart';

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(walletSummaryProvider);
    final transactions = ref.watch(walletTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cüzdan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            summary.when(
              data: (data) {
                if (data == null) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Cüzdan bilgisi bulunamadı.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }

        String formatGold(double value) =>
          '${value.toStringAsFixed(0)} Altın';

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kullanılabilir Bakiye',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${data.availableBalance.toStringAsFixed(0)} Altın',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        Text('Bekleyen: ${formatGold(data.pendingBalance)}'),
                        Text('Toplam Bakiyen: ${formatGold(data.totalEarned)}'),
                        const SizedBox(height: 12),
                        Text(
                          'Son güncelleme: ${DateFormat('dd MMM yyyy HH:mm').format(data.updatedAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Cüzdan bilgisi alınamadı: $error'),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 24),
            Text('Son İşlemler', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            transactions.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Text('Henüz işlem bulunmuyor.');
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, _) => const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final amountStyle = Theme.of(context).textTheme.titleMedium
                        ?.copyWith(
                          color: item.isCredit ? Colors.green : Colors.red,
                        );
                    final sign = item.amount >= 0 ? '+' : '-';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.title),
                      subtitle: Text(
                        '${DateFormat('dd MMM yyyy').format(item.occurredAt)}\n${item.description ?? ''}',
                      ),
                      trailing: Text(
                        '$sign${item.amount.abs().toStringAsFixed(0)} Altın',
                        style: amountStyle,
                      ),
                    );
                  },
                );
              },
              error: (error, _) => Text('İşlemler yüklenemedi: $error'),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
