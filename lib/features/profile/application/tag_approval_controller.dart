import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  TagApprovalController({required TagApprovalRepository repository})
    : _repository = repository,
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
  StreamSubscription<TagApprovalSettings>? _settingsSub;
  StreamSubscription<List<TagApprovalEntry>>? _queueSub;

  Future<void> toggleRequireApproval(bool value) async {
    state = state.copyWith(updatingPreference: true, errorMessage: null);
    try {
      await _repository.updateSettings(
        TagApprovalSettings(requireApproval: value),
      );
    } catch (error) {
      state = state.copyWith(
        updatingPreference: false,
        errorMessage: 'Ayar güncellenemedi: $error',
      );
      return;
    }
    state = state.copyWith(updatingPreference: false);
  }

  Future<void> approve(String entryId) async {
    if (state.processingEntryIds.contains(entryId)) {
      return;
    }
    state = state.copyWith(
      processingEntryIds: {...state.processingEntryIds, entryId},
      errorMessage: null,
    );
    try {
      await _repository.approve(entryId);
    } catch (error) {
      state = state.copyWith(errorMessage: 'Etiket onayı başarısız: $error');
    } finally {
      final nextProcessing = {...state.processingEntryIds}..remove(entryId);
      state = state.copyWith(processingEntryIds: nextProcessing);
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
    try {
      await _repository.reject(entryId);
    } catch (error) {
      state = state.copyWith(errorMessage: 'Etiket reddi başarısız: $error');
    } finally {
      final nextProcessing = {...state.processingEntryIds}..remove(entryId);
      state = state.copyWith(processingEntryIds: nextProcessing);
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
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _queueSub?.cancel();
    super.dispose();
  }
}
