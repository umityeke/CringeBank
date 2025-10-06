import 'package:flutter/material.dart';

import '../models/store_product.dart';
import '../models/store_wallet.dart';
import '../models/user_model.dart';
import '../data/cringestore_repository.dart';
import '../services/cringe_store_service.dart';
import '../services/user_service.dart';
import '../widgets/animated_bubble_background.dart';
import '../widgets/store_product_card.dart';
import 'store_product_detail_screen.dart';

class CringeStoreScreen extends StatefulWidget {
  const CringeStoreScreen({super.key});

  @override
  State<CringeStoreScreen> createState() => _CringeStoreScreenState();
}

class _CringeStoreScreenState extends State<CringeStoreScreen> {
  final _storeRepository = CringeStoreRepository.instance;
  final _userService = UserService.instance;

  late Stream<StoreWallet?> _walletStream;
  late Stream<List<StoreProduct>> _productsStream;

  String _sellerFilter = 'all';
  String _categoryFilter = 'all';

  @override
  void initState() {
    super.initState();
    _walletStream = _storeRepository.watchCurrentWallet();
    _productsStream = _resolveProductsStream();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBubbleBackground(
        child: SafeArea(
          child: StreamBuilder<User?>(
            stream: _userService.userDataStream,
            initialData: _userService.currentUser,
            builder: (context, userSnapshot) {
              final user = userSnapshot.data ?? _userService.currentUser;

              return StreamBuilder<StoreWallet?>(
                stream: _walletStream,
                builder: (context, walletSnapshot) {
                  final wallet = walletSnapshot.data;
                  final walletLoading =
                      walletSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      wallet == null;

                  return StreamBuilder<List<StoreProduct>>(
                    stream: _productsStream,
                    builder: (context, productsSnapshot) {
                      final products = productsSnapshot.data ?? const [];
                      final productsLoading =
                          productsSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          products.isEmpty;
                      final productsError = productsSnapshot.hasError;

                      final size = MediaQuery.of(context).size;
                      final crossAxisCount = size.width >= 1100
                          ? 4
                          : size.width >= 820
                          ? 3
                          : 2;
                      final childAspectRatio = size.width >= 1100
                          ? 0.78
                          : size.width >= 820
                          ? 0.75
                          : 0.72;

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverAppBar(
                            floating: true,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            centerTitle: false,
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.storefront_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Cringe Store',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              child: _WalletSummaryCard(
                                user: user,
                                wallet: wallet,
                                isLoading: walletLoading,
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Filtreler',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSellerFilters(),
                                  const SizedBox(height: 16),
                                  _buildCategoryFilters(),
                                ],
                              ),
                            ),
                          ),
                          if (productsError)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: _ErrorState(),
                            )
                          else if (productsLoading)
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 24,
                              ),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      mainAxisSpacing: 18,
                                      crossAxisSpacing: 18,
                                      childAspectRatio: childAspectRatio,
                                    ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => const _ProductSkeleton(),
                                  childCount: crossAxisCount * 2,
                                ),
                              ),
                            )
                          else if (products.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyState(),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 24,
                              ),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      mainAxisSpacing: 18,
                                      crossAxisSpacing: 18,
                                      childAspectRatio: childAspectRatio,
                                    ),
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final product = products[index];
                                  return StoreProductCard(
                                    product: product,
                                    onTap: () => _openProductDetail(product),
                                  );
                                }, childCount: products.length),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSellerFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          const [
            _SellerFilterChip(value: 'all', label: 'Tümü'),
            _SellerFilterChip(value: 'p2p', label: 'P2P Satıcılar'),
            _SellerFilterChip(value: 'vendor', label: 'Vendor Ürünleri'),
          ].map((chip) {
            final isSelected = chip.value == _sellerFilter;
            return ChoiceChip(
              label: Text(chip.label),
              selected: isSelected,
              onSelected: (_) => _changeSellerFilter(chip.value),
              selectedColor: Colors.orangeAccent.withValues(alpha: 0.25),
              labelStyle: TextStyle(
                color: isSelected ? Colors.orangeAccent : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? Colors.orangeAccent.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.05),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildCategoryFilters() {
    final chips = <Widget>[
      _buildCategoryChip(
        id: 'all',
        label: 'Tüm Kategoriler',
        isSelected: _categoryFilter == 'all',
      ),
    ];

    for (final group in CringeStoreService.categoryGroups) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 6),
          child: Text(
            group.title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      chips.addAll(
        group.subCategories.map(
          (sub) => _buildCategoryChip(
            id: sub.id,
            label: sub.title,
            isSelected: _categoryFilter == sub.id,
          ),
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _buildCategoryChip({
    required String id,
    required String label,
    required bool isSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _changeCategoryFilter(id),
      selectedColor: Colors.deepPurpleAccent.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        color: isSelected ? Colors.deepPurpleAccent : Colors.white70,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Colors.deepPurpleAccent.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
    );
  }

  void _changeSellerFilter(String value) {
    if (_sellerFilter == value) return;
    setState(() {
      _sellerFilter = value;
      _productsStream = _resolveProductsStream();
    });
  }

  void _changeCategoryFilter(String value) {
    if (_categoryFilter == value) return;
    setState(() {
      _categoryFilter = value;
      _productsStream = _resolveProductsStream();
    });
  }

  Stream<List<StoreProduct>> _resolveProductsStream() {
    final category = _categoryFilter == 'all' ? null : _categoryFilter;
    return _storeRepository.watchProducts(
      filter: _sellerFilter,
      category: category,
    );
  }

  void _openProductDetail(StoreProduct product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoreProductDetailScreen(productId: product.id),
      ),
    );
  }
}

class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({
    required this.user,
    required this.wallet,
    required this.isLoading,
  });

  final User? user;
  final StoreWallet? wallet;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ownedCount = user?.ownedStoreItems.length ?? 0;
    final balance = wallet?.goldBalance ?? 0;
    final displayName = () {
      if (user == null) return 'Misafir';
      if (user!.displayName.trim().isNotEmpty) return user!.displayName.trim();
      if (user!.username.trim().isNotEmpty) return '@${user!.username.trim()}';
      return 'Profilin';
    }();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1B2E), Color(0xFF171321)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.monetization_on,
                  color: Colors.orangeAccent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merhaba, $displayName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cüzdanını ve sahip olduğun ürünleri buradan yönetebilirsin.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _WalletStatTile(
                  label: 'Altın Bakiyesi',
                  value: isLoading ? '...' : '$balance',
                  icon: Icons.savings_outlined,
                  accent: Colors.amber,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _WalletStatTile(
                  label: 'Sahip Olduğun Ürün',
                  value: '$ownedCount',
                  icon: Icons.inventory_2_outlined,
                  accent: Colors.deepPurpleAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletStatTile extends StatelessWidget {
  const _WalletStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerFilterChip {
  const _SellerFilterChip({required this.value, required this.label});

  final String value;
  final String label;
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 18,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 16,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Colors.white70,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Filtrelere uyan ürün bulunamadı',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Filtreleri genişlet veya yeni ürünler eklenmesi için marketplace\'i takip et.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off,
                color: Colors.redAccent,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ürünler yüklenirken bir sorun oluştu',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bağlantını kontrol et ve yenile. Sorun devam ederse ekibe haber ver.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
