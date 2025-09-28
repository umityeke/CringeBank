import 'package:flutter/material.dart';

import '../data/store_catalog.dart';
import '../models/user_model.dart';
import 'store_item_artwork.dart';

class StoreInventoryCard extends StatelessWidget {
  final User user;
  final EdgeInsetsGeometry padding;

  const StoreInventoryCard({
    super.key,
    required this.user,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final ownedItems = StoreCatalog.itemsFromIds(user.ownedStoreItems).toList();
    final equippedItems = _resolveEquippedItems();

    return Container(
      padding: padding,
      decoration: BoxDecoration(
  color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Envanterim',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${ownedItems.length} ürün · ${equippedItems.length} aktif',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          if (equippedItems.isNotEmpty) ...[
            _SectionLabel(
              icon: Icons.auto_awesome_rounded,
              label: 'Aktif efektler',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final item = equippedItems[index];
                  return StoreItemArtworkCard(
                    item: item,
                    size: 88,
                    isOwned: true,
                    isEquipped: true,
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: equippedItems.length,
              ),
            ),
            const SizedBox(height: 20),
          ],
          _SectionLabel(
            icon: Icons.inventory_2_rounded,
            label: 'Sahip oldukların',
          ),
          const SizedBox(height: 12),
          if (ownedItems.isEmpty)
            _EmptyStateMessage(color: Colors.white.withValues(alpha: 0.6))
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ownedItems.map((item) {
                final equipped = _isEquipped(item.id);
                return StoreItemArtworkCard(
                  item: item,
                  size: 68,
                  isOwned: true,
                  isEquipped: equipped,
                  dimmed: !equipped,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  List<StoreItem> _resolveEquippedItems() {
    final List<StoreItem> items = [];

    void addIfExists(String? id) {
      final item = id != null ? StoreCatalog.itemById(id) : null;
      if (item != null) items.add(item);
    }

    addIfExists(user.equippedFrameItemId);
    addIfExists(user.equippedNameColorItemId);
    addIfExists(user.equippedBackgroundItemId);
    items.addAll(StoreCatalog.itemsFromIds(user.equippedBadgeItemIds));

    return items;
  }

  bool _isEquipped(String id) {
    if (user.equippedFrameItemId == id) return true;
    if (user.equippedNameColorItemId == id) return true;
    if (user.equippedBackgroundItemId == id) return true;
    return user.equippedBadgeItemIds.contains(id);
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
  Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.65)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyStateMessage extends StatelessWidget {
  final Color color;

  const _EmptyStateMessage({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.hourglass_empty_rounded, size: 18, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Henüz hiç ürünün yok. Cringe Store\'a göz at!',
            style: TextStyle(color: color, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
