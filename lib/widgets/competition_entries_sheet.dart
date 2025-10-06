import 'package:flutter/material.dart';

import '../models/competition_model.dart';
import '../models/cringe_entry.dart';

/// Legacy competition entries bottom sheet placeholder.
/// The old implementation relied on deprecated competition APIs.
/// Until the new experience is ready, we show a simple message so the
/// analyzer stays happy and we avoid runtime crashes if it is invoked.
class CompetitionEntriesSheet extends StatelessWidget {
  const CompetitionEntriesSheet({
    super.key,
    required this.competition,
    this.onEntriesChanged,
  });

  final Competition competition;
  final ValueChanged<List<CringeEntry>>? onEntriesChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  competition.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Yarışma giriş listesi henüz yeni sistemle uyarlanmadı. '
            'Yakında buradan tüm gönderileri inceleyebileceksin.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.75),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
