import 'dart:async';
import 'dart:math';

import '../../domain/models/tag_approval_entry.dart';
import '../../domain/models/tag_approval_settings.dart';
import '../../domain/repositories/tag_approval_repository.dart';

class MockTagApprovalRepository implements TagApprovalRepository {
  MockTagApprovalRepository() {
    _emitQueue();
    _emitSettings();
  }

  final _random = Random(42);
  final List<TagApprovalEntry> _pending = [
    TagApprovalEntry(
      id: 'tag-1001',
      username: 'keremloop',
      displayName: 'Kerem S.',
      avatarUrl:
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAQAAACB4RwKAAAADElEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
      requestedAt: DateTime.now().subtract(const Duration(minutes: 12)),
      flagReason: 'Kullanıcı yeni, otomatik güven filtresinden geçmedi.',
    ),
    TagApprovalEntry(
      id: 'tag-1002',
      username: 'linavirals',
      displayName: 'Lina V.',
      avatarUrl:
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAQAAACB4RwKAAAADElEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
      requestedAt: DateTime.now().subtract(const Duration(minutes: 35)),
      flagReason: 'Haftalık limit üstü etiketleme denemesi.',
    ),
  ];

  TagApprovalSettings _settings = const TagApprovalSettings(requireApproval: true);

  final StreamController<List<TagApprovalEntry>> _queueController =
      StreamController<List<TagApprovalEntry>>.broadcast();
  final StreamController<TagApprovalSettings> _settingsController =
      StreamController<TagApprovalSettings>.broadcast();

  @override
  Stream<List<TagApprovalEntry>> watchQueue() => _queueController.stream;

  @override
  Stream<TagApprovalSettings> watchSettings() => _settingsController.stream;

  @override
  Future<void> updateSettings(TagApprovalSettings settings) async {
    _settings = settings;
    _emitSettings();
    if (!_settings.requireApproval && _pending.isNotEmpty) {
      // Auto-approve everything when queue is disabled.
      for (final entry in List<TagApprovalEntry>.from(_pending)) {
        await approve(entry.id);
      }
    }
  }

  @override
  Future<void> approve(String entryId) async {
    final index = _pending.indexWhere((entry) => entry.id == entryId);
    if (index == -1) {
      return;
    }
    _pending.removeAt(index);
    _emitQueue();
  }

  @override
  Future<void> reject(String entryId) async {
    final index = _pending.indexWhere((entry) => entry.id == entryId);
    if (index == -1) {
      return;
    }
    _pending.removeAt(index);
    // Simulate that rejecting sometimes adds another entry later.
    if (_pending.length < 2 && _settings.requireApproval) {
      _pending.add(
        TagApprovalEntry(
          id: 'tag-${_random.nextInt(9000) + 1000}',
          username: 'guest${_random.nextInt(99)}',
          displayName: 'Yeni Kullanıcı',
          avatarUrl:
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAQAAACB4RwKAAAADElEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
          requestedAt: DateTime.now(),
          flagReason: 'Otomatik dengeleyici örnek etiketi.',
        ),
      );
    }
    _emitQueue();
  }

  void _emitQueue() {
    if (!_queueController.isClosed) {
      _queueController.add(List<TagApprovalEntry>.unmodifiable(_pending));
    }
  }

  void _emitSettings() {
    if (!_settingsController.isClosed) {
      _settingsController.add(_settings);
    }
  }

  @override
  Future<void> dispose() async {
    await _queueController.close();
    await _settingsController.close();
  }
}
