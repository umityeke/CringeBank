import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/store_product.dart';
import '../models/store_wallet.dart';
import '../models/user_model.dart';
import '../services/cringe_store_service.dart';
import '../services/user_service.dart';
import '../utils/profile_navigation.dart';

/// ürün detay ekranı - Escrow ile satın alma
class StoreProductDetailScreen extends StatefulWidget {
  final String productId;

  const StoreProductDetailScreen({super.key, required this.productId});

  @override
  State<StoreProductDetailScreen> createState() =>
      _StoreProductDetailScreenState();
}

class _StoreProductDetailScreenState extends State<StoreProductDetailScreen> {
  final _storeService = CringeStoreService();
  bool _isPurchasing = false;
  late final Stream<StoreWallet?> _walletStream;
  Future<User?>? _sellerFuture;
  User? _sellerCache;
  Future<bool>? _shareStatusFuture;
  bool? _hasSharedProduct;
  bool _isSharingProduct = false;
  late final PageController _imagePageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _walletStream = _storeService.getCurrentWallet();
    _imagePageController = PageController();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ürün Detayı')),
      body: FutureBuilder<StoreProduct?>(
        future: _storeService.getProduct(widget.productId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final product = snapshot.data;
          if (product == null) {
            return const Center(child: Text('ürün bulunamadı'));
          }

          return _buildProductContent(product);
        },
      ),
    );
  }

  Widget _buildProductContent(StoreProduct product) {
    final needsSeller =
        product.isP2P && (product.sellerId?.trim().isNotEmpty ?? false);
    if (needsSeller) {
      _sellerFuture ??= UserService.instance.getUserById(
        product.sellerId!.trim(),
      );
      return FutureBuilder<User?>(
        future: _sellerFuture,
        builder: (context, sellerSnapshot) {
          if (sellerSnapshot.connectionState == ConnectionState.done) {
            _sellerCache = sellerSnapshot.data;
          }
          final seller = sellerSnapshot.data ?? _sellerCache;
          final isLoadingSeller =
              sellerSnapshot.connectionState == ConnectionState.waiting &&
              seller == null;
          return _buildProductBody(
            product,
            seller: seller,
            isSellerLoading: isLoadingSeller,
          );
        },
      );
    }

    _sellerCache = null;
    return _buildProductBody(product);
  }

  Widget _buildProductBody(
    StoreProduct product, {
    User? seller,
    bool isSellerLoading = false,
  }) {
    _shareStatusFuture ??= _storeService.isProductShared(product.id);

    return FutureBuilder<bool>(
      future: _shareStatusFuture,
      builder: (context, shareSnapshot) {
        if (shareSnapshot.connectionState == ConnectionState.done) {
          _hasSharedProduct = shareSnapshot.data ?? false;
        }
        final hasShared = shareSnapshot.data ?? _hasSharedProduct ?? false;
        final isShareLoading =
            shareSnapshot.connectionState == ConnectionState.waiting &&
            _hasSharedProduct == null;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageCarousel(product.images),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(product),
                    const SizedBox(height: 16),
                    _buildSellerSection(
                      product,
                      seller: seller,
                      isLoading: isSellerLoading,
                    ),
                    if (product.isP2P && product.status == 'sold') ...[
                      const SizedBox(height: 16),
                      _buildSoldSharePanel(
                        product,
                        seller: seller,
                        isShareLoading: isShareLoading,
                        hasShared: hasShared,
                      ),
                    ],
                    const Divider(height: 32),
                    _buildDescription(product),
                    const Divider(height: 32),
                    _buildDetails(
                      product,
                      seller: seller,
                      isSellerLoading: isSellerLoading,
                    ),
                    const SizedBox(height: 24),
                    _buildPurchaseSection(product),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 300,
        color: Colors.grey[200],
        child: const Icon(Icons.image, size: 80),
      );
    }

    final hasMultipleImages = images.length > 1;

    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _imagePageController,
            itemCount: images.length,
            onPageChanged: (index) {
              if (_currentImageIndex != index && mounted) {
                setState(() => _currentImageIndex = index);
              }
            },
            itemBuilder: (context, index) {
              final url = images[index];
              return CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, size: 80),
                ),
              );
            },
          ),
          if (hasMultipleImages)
            Positioned(
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    for (int i = 0; i < images.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentImageIndex == i ? 12 : 8,
                        height: _currentImageIndex == i ? 12 : 8,
                        decoration: BoxDecoration(
                          color: _currentImageIndex == i
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(StoreProduct product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (product.isP2P)
              const Chip(
                label: Text('P2P'),
                avatar: Icon(Icons.people, size: 16),
              ),
            if (product.isVendor)
              const Chip(
                label: Text('Vendor'),
                avatar: Icon(Icons.store, size: 16),
              ),
            const SizedBox(width: 8),
            Chip(
              label: Text(product.condition == 'new' ? 'Yeni' : 'İkinci El'),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                CringeStoreService.getCategoryDisplayName(product.category),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          product.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.monetization_on, size: 32, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              '${product.priceGold} Altın',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.amber[700],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription(StoreProduct product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Açıklama',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(product.desc, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }

  Widget _buildDetails(
    StoreProduct product, {
    User? seller,
    bool isSellerLoading = false,
  }) {
    final sellerName = () {
      if (!product.isP2P) return null;
      if (isSellerLoading) return 'Yükleniyor...';
      if (seller != null) {
        return _resolveDisplayName(seller);
      }
      return product.sellerId ?? '-';
    }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detaylar',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _DetailRow(
          label: 'Kategori',
          value: CringeStoreService.getCategoryDisplayName(product.category),
        ),
        _DetailRow(
          label: 'Durum',
          value: product.condition == 'new' ? 'Yeni' : 'İkinci El',
        ),
        _DetailRow(
          label: 'Satıcı Tipi',
          value: product.isP2P ? 'P2P (Kullanıcı)' : 'Vendor (Platform)',
        ),
        if (sellerName != null) _DetailRow(label: 'Satıcı', value: sellerName),
        _DetailRow(
          label: 'Stok Durumu',
          value: product.isActive ? 'Mevcut' : 'Tükendi',
        ),
      ],
    );
  }

  Widget _buildPurchaseSection(StoreProduct product) {
    switch (product.status) {
      case 'sold':
        return _buildSaleStatusCard(
          icon: Icons.verified_rounded,
          title: 'Bu ürün satıldı',
          message:
              'Satışı gerçekleğtiren kullanıcı profilinde bu ürünü paylaşabilir. Escrow süreci tamamlandığında altınlar serbest bırakılır.',
          color: Colors.green[600],
        );
      case 'reserved':
        return _buildSaleStatusCard(
          icon: Icons.hourglass_top,
          title: 'ürün rezerve edildi',
          message:
              'Satıcı ve alıcı arasındaki escrow işlemi devam ediyor. ürün yeniden satığa açılana kadar satın alma yapılamaz.',
          color: Colors.amber[700],
        );
      case 'canceled':
        return _buildSaleStatusCard(
          icon: Icons.cancel_outlined,
          title: 'Satığ iptal edildi',
          message:
              'Bu ürün için açılan satığ işlemi sona erdirildi. Satıcı tarafından yeniden listelenene kadar satın alma yapılamaz.',
          color: Colors.red[600],
        );
    }

    final commission = CringeStoreService.calculateCommission(
      product.priceGold,
    );
    final totalCost = CringeStoreService.calculateTotalCost(product.priceGold);

    return StreamBuilder<StoreWallet?>(
      stream: _walletStream,
      builder: (context, snapshot) {
        final textTheme = Theme.of(context).textTheme;
        final wallet = snapshot.data;
        final balance = wallet?.goldBalance ?? 0;
        final hasEnoughBalance = balance >= totalCost;
        final shortage = totalCost - balance;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryRow(
                    label: 'ürün Fiyatı',
                    value: '${product.priceGold} Altın',
                  ),
                  _SummaryRow(
                    label: 'Komisyon (%5)',
                    value: '$commission Altın',
                    labelStyle: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    valueStyle: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: 'Toplam Ödenecek',
                    value: '$totalCost Altın',
                    valueStyle: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Cüzdan Bakiyesi',
                    value: '$balance Altın',
                    valueStyle: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: hasEnoughBalance
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                  ),
                  if (!hasEnoughBalance)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Bu işlemi tamamlamak için ${shortage.abs()} Altın daha gerekli.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (product.isActive && hasEnoughBalance)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isPurchasing
                      ? null
                      : () => _handlePurchase(product),
                  icon: _isPurchasing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shopping_cart),
                  label: Text(
                    _isPurchasing
                        ? 'İğleniyor...'
                        : 'Satın Al (Toplam $totalCost Altın)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isPurchasing ? null : _showBuyGoldHelp,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text(
                        'Altın bakiyesi yetersiz',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[400],
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _showBuyGoldHelp,
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text('Altın nasıl yüklenir?'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Future<void> _handlePurchase(StoreProduct product) async {
    if (_isPurchasing) return;

    final commission = CringeStoreService.calculateCommission(
      product.priceGold,
    );
    final totalCost = CringeStoreService.calculateTotalCost(product.priceGold);

    StoreWallet? wallet;
    try {
      wallet = await _walletStream.first;
    } catch (_) {
      wallet = null;
    }

    if (!mounted) return;

    final balance = wallet?.goldBalance ?? 0;

    if (balance < totalCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Altın bakiyesi yetersiz. Toplam gereken: $totalCost Altın (mevcut: $balance Altın).',
          ),
        ),
      );
      await _showBuyGoldHelp();
      return;
    }

    // Confirm purchase
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Satın Al'),
        content: Text(
          'ürün fiyatı: ${product.priceGold} Altın\n'
          'Komisyon (%5): $commission Altın\n'
          'Toplam: $totalCost Altın\n\n'
          'Altınlarınız escrow sistemine kilitlenecek ve satıcı onayladıktan sonra transfer edilecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Satın Al'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isPurchasing = true);

    try {
      final result = await _storeService.lockEscrow(product.id);

      if (!mounted) return;

      if (result['ok'] == true) {
        final orderId = result['orderId'];
        final successMessage = orderId == null
            ? 'Sipariş oluşturuldu!'
            : 'Sipariş oluşturuldu! Sipariş ID: $orderId';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to store list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${result['error'] ?? 'Bilinmeyen hata'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alma hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _showBuyGoldHelp() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Altın nasıl yüklenir?'),
        content: const Text(
          'Altın bakiyeni Cringe Bankası hesabındaki Cüzdan bölümünden yükleyebilirsin. '
          'Henüz uygulama içi altın satışına eriğimin yoksa destek ekibiyle iletiğime geçmeyi unutma.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleStatusCard({
    required IconData icon,
    required String title,
    required String message,
    Color? color,
  }) {
    final iconColor = color ?? Colors.black87;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoldSharePanel(
    StoreProduct product, {
    User? seller,
    required bool isShareLoading,
    required bool hasShared,
  }) {
    final theme = Theme.of(context);
    final baseColor = Colors.deepPurple;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: baseColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_rounded, color: baseColor, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Satışı profilinde paylaş',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: baseColor.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Satılan ürünün kreplerde tüm etkileğimleri alacak ğekilde paylaşılır ve profilinde görünür. ',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87),
          ),
          const SizedBox(height: 12),
          if (isShareLoading)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const LinearProgressIndicator(minHeight: 6),
            )
          else if (hasShared)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Bu satığ zaten paylaşıldı.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (seller != null)
                  OutlinedButton.icon(
                    onPressed: () => openUserProfile(
                      context,
                      userId: seller.id,
                      initialUser: seller,
                    ),
                    icon: const Icon(Icons.person_pin_circle_rounded),
                    label: const Text('Profili görüntüle'),
                  ),
              ],
            )
          else if (seller == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Satıcı bilgileri yüklenemediği için paylaşım yapılamıyor.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Satışı kreplerde paylaşarak tüm kullanıcıların görmesini sağlayabilirsin.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSharingProduct
                        ? null
                        : () => _handleShareProduct(product, seller),
                    icon: _isSharingProduct
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.rocket_launch_rounded),
                    label: Text(
                      _isSharingProduct ? 'Paylaşılıyor...' : 'Satışı Kreple',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: baseColor.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _handleShareProduct(StoreProduct product, User seller) async {
    if (_isSharingProduct) return;

    setState(() => _isSharingProduct = true);

    try {
      final result = await _storeService.shareSoldProduct(
        product: product,
        seller: seller,
      );
      if (!mounted) return;

      if (result.success || result.alreadyShared) {
        setState(() {
          _hasSharedProduct = true;
          _shareStatusFuture = Future.value(true);
        });
      }

      final Color backgroundColor;
      if (result.success) {
        backgroundColor = Colors.green;
      } else if (result.alreadyShared) {
        backgroundColor = Colors.blueGrey;
      } else {
        backgroundColor = Colors.red;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: backgroundColor,
          action:
              (result.entryId != null &&
                  (result.success || result.alreadyShared))
              ? SnackBarAction(
                  label: 'Profili Aç',
                  textColor: Colors.white,
                  onPressed: () => openUserProfile(
                    context,
                    userId: seller.id,
                    initialUser: seller,
                  ),
                )
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paylaşım sırasında hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharingProduct = false);
      }
    }
  }

  Widget _buildSellerSection(
    StoreProduct product, {
    User? seller,
    required bool isLoading,
  }) {
    if (product.isP2P) {
      if (isLoading) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const CircleAvatar(radius: 28, backgroundColor: Colors.white70),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      final displaySeller = seller;
      if (displaySeller == null) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Satıcı bilgileri yüklenemedi. Satıcı ID: ${product.sellerId ?? '-'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
      }

      final displayName = _resolveDisplayName(displaySeller);
      final handle = displaySeller.username.trim().isNotEmpty
          ? '@${displaySeller.username.trim()}'
          : '@${displaySeller.id.substring(0, displaySeller.id.length > 12 ? 12 : displaySeller.id.length)}';

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            _buildSellerAvatar(displaySeller),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    handle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu ürün $displayName tarafından listelendi.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => openUserProfile(
                context,
                userId: displaySeller.id,
                initialUser: displaySeller,
              ),
              icon: const Icon(Icons.person_search, size: 18),
              label: const Text('Profili Gör'),
            ),
          ],
        ),
      );
    }

    if (product.isVendor) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueGrey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey[100]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.blueGrey[200],
              child: const Icon(Icons.storefront, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resmi Satıcı',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.vendorId ?? 'CringeBank Vendor',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.blueGrey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu ürün Cringe Bankası tarafından doğrulanmığ bir vendor üzerinden satılmaktadır.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blueGrey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSellerAvatar(User seller) {
    final avatar = seller.avatar.trim();
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: CachedNetworkImageProvider(avatar),
        backgroundColor: Colors.grey[200],
      );
    }

    final initials = _extractInitials(
      seller.displayName.isNotEmpty ? seller.displayName : seller.username,
    );

    final display = avatar.isNotEmpty && avatar.length <= 3 ? avatar : initials;

    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.grey[300],
      child: Text(
        display,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _extractInitials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'CB';
    final parts = trimmed.split(RegExp(r'\s+'));
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part.isEmpty) continue;
      buffer.write(part.characters.first.toUpperCase());
      if (buffer.length == 2) break;
    }
    return buffer.isEmpty
        ? trimmed.characters.first.toUpperCase()
        : buffer.toString();
  }

  String _resolveDisplayName(User user) {
    if (user.displayName.trim().isNotEmpty) {
      return user.displayName.trim();
    }
    if (user.fullName.trim().isNotEmpty) {
      return user.fullName.trim();
    }
    if (user.username.trim().isNotEmpty) {
      return user.username.trim();
    }
    return user.id;
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style:
                labelStyle ??
                theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
          ),
          Text(
            value,
            style:
                valueStyle ??
                theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
