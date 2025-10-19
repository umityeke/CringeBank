import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/telemetry/telemetry_service.dart';
import '../../../core/telemetry/telemetry_utils.dart';
import '../domain/models/tag_approval_entry.dart';
import '../domain/models/tag_approval_settings.dart';
import '../domain/repositories/tag_approval_repository.dart';

class TagApprovalState {
  const TagApprovalState({
    required this.isLoading,
    required this.requireApproval,
    required this.pending,
    required this.updatingPreference,
    required this.processingEntryIds,
    this.errorMessage,
  });

  factory TagApprovalState.initial() {
    return const TagApprovalState(
      isLoading: true,
      requireApproval: true,
      pending: <TagApprovalEntry>[],
      updatingPreference: false,
      processingEntryIds: <String>{},
      errorMessage: null,
    );
  }

  final bool isLoading;
  final bool requireApproval;
  final List<TagApprovalEntry> pending;
  final bool updatingPreference;
  final Set<String> processingEntryIds;
  final String? errorMessage;

  TagApprovalState copyWith({
    bool? isLoading,
    bool? requireApproval,
    List<TagApprovalEntry>? pending,
    bool? updatingPreference,
    Set<String>? processingEntryIds,
    String? errorMessage,
  }) {
    return TagApprovalState(
      isLoading: isLoading ?? this.isLoading,
      requireApproval: requireApproval ?? this.requireApproval,
      pending: pending ?? this.pending,
      updatingPreference: updatingPreference ?? this.updatingPreference,
      processingEntryIds: processingEntryIds ?? this.processingEntryIds,
      errorMessage: errorMessage,
    );
  }
}

class TagApprovalController extends StateNotifier<TagApprovalState> {
  TagApprovalController({
    required TagApprovalRepository repository,
    TelemetryService? telemetry,
    DateTime Function()? now,
  })  : _repository = repository,
        _telemetry = telemetry,
        _now = now ?? DateTime.now,
        super(TagApprovalState.initial()) {
    _settingsSub = _repository.watchSettings().listen(
      _handleSettings,
      onError: _handleError,
    );
    _queueSub = _repository.watchQueue().listen(
      _handleQueue,
      onError: _handleError,
    );
  }

  final TagApprovalRepository _repository;
  final TelemetryService? _telemetry;
  final DateTime Function() _now;
  StreamSubscription<TagApprovalSettings>? _settingsSub;
  StreamSubscription<List<TagApprovalEntry>>? _queueSub;

  void _emitPreferenceChange({
    required bool requireApproval,
    required String status,
    String? reason,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final attributes = <String, Object?>{
      'requireApproval': requireApproval,
      'status': status,
      'pendingCount': state.pending.length,
      'reason': reason,
    }..removeWhere((_, value) => value == null);
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.tagApprovalPreferenceChanged,
          timestamp: _now().toUtc(),
          attributes: attributes,
        ),
      ),
    );
  }

  void _emitDecision({
    required String entryId,
    required String action,
    required String status,
    String? reason,
    TagApprovalEntry? entry,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final attributes = <String, Object?>{
      'entryIdHash': hashIdentifier(entryId),
      'action': action,
      'status': status,
      'reason': reason,
      'hasFlag': entry?.flagReason != null,
      'flagReason': entry?.flagReason,
      'requestAgeSeconds': entry == null
          ? null
          : _now().difference(entry.requestedAt).inSeconds,
    }..removeWhere((_, value) => value == null);
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.tagApprovalDecision,
          timestamp: _now().toUtc(),
          attributes: attributes,
        ),
      ),
    );
  }

  void _emitError({required String context, required Object error}) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final attributes = <String, Object?>{
      'context': context,
      'errorType': error.runtimeType.toString(),
      'message': error.toString(),
      'pendingCount': state.pending.length,
    };
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.tagApprovalError,
          timestamp: _now().toUtc(),
          attributes: attributes,
        ),
      ),
    );
  }

  Future<void> toggleRequireApproval(bool value) async {
    state = state.copyWith(updatingPreference: true, errorMessage: null);
    _emitPreferenceChange(requireApproval: value, status: 'pending');
    try {
      await _repository.updateSettings(
        TagApprovalSettings(requireApproval: value),
      );
    } catch (error) {
      state = state.copyWith(
        updatingPreference: false,
        errorMessage: 'Ayar güncellenemedi: $error',
      );
      _emitPreferenceChange(
        requireApproval: value,
        status: 'failure',
        reason: 'update_failed',
      );
      _emitError(context: 'toggleRequireApproval', error: error);
      return;
    }
    state = state.copyWith(updatingPreference: false);
    _emitPreferenceChange(requireApproval: value, status: 'success');
  }

  Future<void> approve(String entryId) async {
    if (state.processingEntryIds.contains(entryId)) {
      return;
    }
    state = state.copyWith(
      processingEntryIds: {...state.processingEntryIds, entryId},
      errorMessage: null,
    );
    final entry = _findEntry(entryId);
    _emitDecision(entryId: entryId, action: 'approve', status: 'pending', entry: entry);
    var succeeded = false;
    try {
      await _repository.approve(entryId);
      succeeded = true;
    } catch (error) {
      state = state.copyWith(errorMessage: 'Etiket onayı başarısız: $error');
      _emitDecision(
        entryId: entryId,
        action: 'approve',
        status: 'failure',
        reason: 'approve_failed',
        entry: entry,
      );
      _emitError(context: 'approve', error: error);
    } finally {
      final nextProcessing = {...state.processingEntryIds}..remove(entryId);
      state = state.copyWith(processingEntryIds: nextProcessing);
    }
    if (succeeded) {
      _emitDecision(
        entryId: entryId,
        action: 'approve',
        status: 'success',
        entry: entry,
      );
    }
  }

  Future<void> reject(String entryId) async {
    if (state.processingEntryIds.contains(entryId)) {
      return;
    }
    state = state.copyWith(
      processingEntryIds: {...state.processingEntryIds, entryId},
      errorMessage: null,
    );
    final entry = _findEntry(entryId);
    _emitDecision(entryId: entryId, action: 'reject', status: 'pending', entry: entry);
    var succeeded = false;
    try {
      await _repository.reject(entryId);
      succeeded = true;
    } catch (error) {
      state = state.copyWith(errorMessage: 'Etiket reddi başarısız: $error');
      _emitDecision(
        entryId: entryId,
        action: 'reject',
        status: 'failure',
        reason: 'reject_failed',
        entry: entry,
      );
      _emitError(context: 'reject', error: error);
    } finally {
      final nextProcessing = {...state.processingEntryIds}..remove(entryId);
      state = state.copyWith(processingEntryIds: nextProcessing);
    }
    if (succeeded) {
      _emitDecision(
        entryId: entryId,
        action: 'reject',
        status: 'success',
        entry: entry,
      );
    }
  }

  void _handleSettings(TagApprovalSettings settings) {
    state = state.copyWith(
      requireApproval: settings.requireApproval,
      isLoading: false,
    );
  }

  void _handleQueue(List<TagApprovalEntry> queue) {
    state = state.copyWith(pending: queue, isLoading: false);
  }

  void _handleError(Object error, [StackTrace? _]) {
    state = state.copyWith(
      isLoading: false,
      errorMessage: 'Etiket kuyruğu güncellenemedi: $error',
    );
    _emitError(context: 'stream', error: error);
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _queueSub?.cancel();
    super.dispose();
  }

  TagApprovalEntry? _findEntry(String entryId) {
    try {
      return state.pending.firstWhere((entry) => entry.id == entryId);
    } catch (_) {
      return null;
    }
  }
}
