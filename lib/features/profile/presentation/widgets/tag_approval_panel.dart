import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_card.dart';
import '../../application/tag_approval_providers.dart';
import '../../domain/models/tag_approval_entry.dart';

class TagApprovalPanel extends ConsumerWidget {
  const TagApprovalPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tagApprovalControllerProvider);
    final controller = ref.read(tagApprovalControllerProvider.notifier);
    final theme = Theme.of(context);
    final pending = state.pending;

    return AppCard(
      key: const Key('tagApprovalPanel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Etiket Onayı', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Topluluk üyelerinin seni etiketlediği içerikleri yayınlamadan önce incele.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            key: const Key('tagApprovalToggle'),
            value: state.requireApproval,
            onChanged: state.updatingPreference
                ? null
                : (value) => unawaited(controller.toggleRequireApproval(value)),
            contentPadding: EdgeInsets.zero,
            title: const Text('Etiketler için onay iste'),
            subtitle: const Text(
              'Kapalıyken tüm etiketler otomatik olarak yayınlanır.',
            ),
          ),
          if (state.updatingPreference)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else
            const SizedBox(height: 12),
          if (state.errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                state.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          if (state.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (!state.requireApproval)
            Text(
              'Onay kuyruğu kapalı. Etiketler otomatik olarak profilinde yayınlanır.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else if (pending.isEmpty)
            Text(
              'Şu anda onay bekleyen etiket yok.',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            Text('Onay bekleyenler', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Column(
              children: pending
                  .map(
                    (entry) => _PendingTagTile(
                      entry: entry,
                      isProcessing: state.processingEntryIds.contains(entry.id),
                      onApprove: () => controller.approve(entry.id),
                      onReject: () => controller.reject(entry.id),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingTagTile extends StatelessWidget {
  const _PendingTagTile({
    required this.entry,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final TagApprovalEntry entry;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarBytes = _decodeDataUri(entry.avatarUrl);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: avatarBytes != null
                    ? MemoryImage(avatarBytes)
                    : null,
                child: avatarBytes == null
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${entry.username} · ${_formatRelativeTime(entry.requestedAt)}',
                      style: subtitleStyle,
                    ),
                    if (entry.flagReason != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          entry.flagReason!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('tagApprovalReject_${entry.id}'),
                  onPressed: isProcessing ? null : onReject,
                  icon: const Icon(Icons.block),
                  label: const Text('Reddet'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: Key('tagApprovalApprove_${entry.id}'),
                  onPressed: isProcessing ? null : onApprove,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Onayla'),
                ),
              ),
            ],
          ),
          if (isProcessing)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

Uint8List? _decodeDataUri(String uri) {
  if (!uri.startsWith('data:image')) {
    return null;
  }
  return Uri.parse(uri).data?.contentAsBytes();
}

String _formatRelativeTime(DateTime timestamp) {
  final delta = DateTime.now().difference(timestamp);
  if (delta.inMinutes < 1) {
    return 'az önce';
  }
  if (delta.inMinutes < 60) {
    return '${delta.inMinutes} dk önce';
  }
  if (delta.inHours < 24) {
    return '${delta.inHours} sa önce';
  }
  return '${delta.inDays} gün önce';
}
