import 'package:flutter/material.dart';
import '../models/cringe_entry.dart';

class CringeCard extends StatelessWidget {
  final CringeEntry entry;
  final VoidCallback? onTap;

  const CringeCard({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildTitle(),
              const SizedBox(height: 8),
              _buildDescription(),
              const SizedBox(height: 12),
              _buildTags(),
              const SizedBox(height: 12),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getCategoryColor().withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getCategoryColor().withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.kategori.emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                entry.kategori.displayName,
                style: TextStyle(
                  color: _getCategoryColor(),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (entry.isPremiumCringe) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'PREMIUM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        _buildKrepLevel(),
      ],
    );
  }

  Widget _buildKrepLevel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: _getKrepGradient()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            entry.krepSeviyesi.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      entry.baslik,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDescription() {
    return Text(
      entry.aciklama,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.8),
        fontSize: 14,
        height: 1.4,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTags() {
    if (entry.etiketler.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: entry.etiketler.take(4).map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
          ),
          child: Text(
            '#$tag',
            style: TextStyle(
              color: Colors.purple.shade200,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        if (entry.isAnonim) ...[
          Icon(
            Icons.visibility_off,
            size: 14,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            'Anonim',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 16),
        ],
        Icon(
          Icons.access_time,
          size: 14,
          color: Colors.white.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 4),
        Text(
          _formatTimeAgo(entry.createdAt),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        const Spacer(),
        _buildStatChip(Icons.favorite_border, entry.begeniSayisi),
        const SizedBox(width: 12),
        _buildStatChip(Icons.comment_outlined, entry.yorumSayisi),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor() {
    switch (entry.kategori) {
      case CringeCategory.askAcisiKrepligi:
        return Colors.pink;
      case CringeCategory.aileSofrasiFelaketi:
        return Colors.orange;
      case CringeCategory.isGorusmesiKatliam:
        return Colors.blue;
      case CringeCategory.sosyalMedyaIntihari:
        return Colors.purple;
      case CringeCategory.fizikselRezillik:
        return Colors.green;
      case CringeCategory.sosyalRezillik:
        return Colors.indigo;
      case CringeCategory.aileselRezaletler:
        return Colors.teal;
      case CringeCategory.okullDersDramlari:
        return Colors.cyan;
      case CringeCategory.sarhosPismanliklari:
        return Colors.amber;
    }
  }

  List<Color> _getKrepGradient() {
    if (entry.krepSeviyesi <= 3) {
      return [Colors.green, Colors.lightGreen];
    } else if (entry.krepSeviyesi <= 6) {
      return [Colors.orange, Colors.deepOrange];
    } else {
      return [Colors.red, Colors.pink];
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}g';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}s';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}dk';
    } else {
      return 'şimdi';
    }
  }
}
