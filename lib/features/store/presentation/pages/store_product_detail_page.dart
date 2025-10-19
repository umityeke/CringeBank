import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cringebank/models/store_product.dart' as store_model;

import '../../application/store_providers.dart';

class StoreProductDetailPage extends ConsumerWidget {
  const StoreProductDetailPage({
    required this.productId,
    this.initialProduct,
    super.key,
  });

  final String productId;
  final store_model.StoreProduct? initialProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(storeProductProvider(productId));
    final latestProduct = productAsync.maybeWhen(
      data: (value) => value,
      orElse: () => initialProduct,
    );

    return Scaffold(
      appBar: AppBar(title: Text(latestProduct?.title ?? 'Ürün $productId')),
      body: productAsync.when(
        data: (product) => _ProductContent(product: product ?? initialProduct),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Ürün detayları yüklenemedi: $error'),
          ),
        ),
        loading: () => _ProductContent(product: latestProduct),
      ),
    );
  }
}

class _ProductContent extends StatelessWidget {
  const _ProductContent({required this.product});

  final store_model.StoreProduct? product;

  @override
  Widget build(BuildContext context) {
    if (product == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product!.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            product!.desc.isNotEmpty
                ? product!.desc
                : 'Bu ürün için detaylı bilgi henüz eklenmedi.',
          ),
          const SizedBox(height: 16),
          Text(
            'Fiyat: ${product!.priceGold} Altın',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          if (product!.images.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: product!.images
                  .map(
                    (url) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
