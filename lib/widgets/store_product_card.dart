import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/store_product.dart';
import '../services/cringe_store_service.dart';

class StoreProductCard extends StatelessWidget {
  const StoreProductCard({super.key, required this.product, this.onTap});

  final StoreProduct product;
  final VoidCallback? onTap;

  static const _placeholderGradient = LinearGradient(
    colors: [Color(0xFF1E1B2D), Color(0xFF15121E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = product.images.isNotEmpty ? product.images.first : null;
    final status = _ProductStatus.from(product.status);
    final sellerLabel = product.isP2P
        ? 'P2P Satıcı'
        : product.isVendor
        ? 'Vendor'
        : 'Platform';
    final sellerColor = product.isP2P
        ? Colors.orange
        : product.isVendor
        ? Colors.blueAccent
        : Colors.deepPurpleAccent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageHeader(imageUrl, status),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(
                          label: sellerLabel,
                          backgroundColor: sellerColor.withValues(alpha: 0.16),
                          foregroundColor: sellerColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${product.priceGold} Altın',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.amber[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(
                          label: CringeStoreService.getCategoryDisplayName(
                            product.category,
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white70,
                        ),
                        _StatusPill(
                          label: product.condition == 'new'
                              ? 'Yeni'
                              : 'İkinci El',
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                          foregroundColor: Colors.greenAccent,
                        ),
                        if (status.isHighlight)
                          _StatusPill(
                            label: status.label,
                            backgroundColor: status.color.withValues(
                              alpha: 0.14,
                            ),
                            foregroundColor: status.color,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageHeader(String? imageUrl, _ProductStatus status) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  decoration: const BoxDecoration(
                    gradient: _placeholderGradient,
                  ),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: const BoxDecoration(
                    gradient: _placeholderGradient,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.white54,
                    size: 36,
                  ),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(gradient: _placeholderGradient),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            if (status.isHighlight)
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _StatusPill(
                    label: status.label,
                    backgroundColor: status.color.withValues(alpha: 0.85),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ProductStatus {
  const _ProductStatus._(this.label, this.color, this.isHighlight);

  final String label;
  final Color color;
  final bool isHighlight;

  static _ProductStatus from(String raw) {
    switch (raw) {
      case 'sold':
        return _ProductStatus._('Satıldı', Colors.redAccent, true);
      case 'reserved':
        return _ProductStatus._('Rezerve', Colors.amber, true);
      case 'canceled':
        return _ProductStatus._('İptal', Colors.grey, true);
      case 'active':
      default:
        return _ProductStatus._('Satışta', Colors.greenAccent, false);
    }
  }
}
