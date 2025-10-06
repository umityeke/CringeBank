import 'package:flutter/material.dart';

import '../models/competition_model.dart';

/// Legacy quick entry bottom sheet placeholder.
/// The original implementation depended on removed competition service APIs.
/// This lightweight version keeps navigation stable while the new flow is
/// implemented.
class CompetitionQuickEntrySheet extends StatelessWidget {
  const CompetitionQuickEntrySheet({super.key, required this.competition});

  final Competition competition;

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
            'Bu yarışma için hızlı katılım akışı henüz hazır değil. '
            'Anını paylaşmak için ana yarışma ekranındaki yönergeleri takip et.',
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
