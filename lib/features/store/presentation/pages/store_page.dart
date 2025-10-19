import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/store_providers.dart';

class StorePage extends ConsumerWidget {
  const StorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(storeCatalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('CringeStore')),
      body: catalog.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(
              child: Text('Şu anda vitrin boş. Yakında yeni ürünler geliyor!'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (context, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                child: ListTile(
                  title: Text(product.title),
                  subtitle:
                      Text(product.desc.isNotEmpty ? product.desc : 'Detay yakında'),
                  trailing: Text('${product.priceGold} Altın'),
                  onTap: () {
                    context.goNamed(
                      'store-product-detail',
                      pathParameters: {'productId': product.id},
                      extra: product,
                    );
                  },
                ),
              );
            },
          );
        },
        error: (error, _) =>
            Center(child: Text('Mağaza yüklenirken hata oluştu: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
