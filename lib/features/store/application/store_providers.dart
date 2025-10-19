import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cringebank/core/di/service_locator.dart';
import 'package:cringebank/data/cringestore_repository.dart';
import 'package:cringebank/models/store_product.dart' as store_model;

final storeRepositoryProvider = Provider<CringeStoreRepository>((ref) {
  return sl<CringeStoreRepository>();
});

final storeCatalogProvider = StreamProvider<List<store_model.StoreProduct>>((
  ref,
) {
  final repository = ref.watch(storeRepositoryProvider);
  return repository.watchProducts();
});

final storeProductProvider = StreamProvider.family<store_model.StoreProduct?, String>(
  (ref, productId) {
    final repository = ref.watch(storeRepositoryProvider);
    return repository.watchProduct(productId);
  },
);
