import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/feed_segment.dart';

@immutable
class FeedLazyLoaderState {
  const FeedLazyLoaderState({
    required this.visibleCount,
    required this.chunkSize,
  });

  factory FeedLazyLoaderState.initial(int chunkSize) {
    return FeedLazyLoaderState(visibleCount: 0, chunkSize: chunkSize);
  }

  final int visibleCount;
  final int chunkSize;

  FeedLazyLoaderState copyWith({int? visibleCount, int? chunkSize}) {
    return FeedLazyLoaderState(
      visibleCount: visibleCount ?? this.visibleCount,
      chunkSize: chunkSize ?? this.chunkSize,
    );
  }
}

class FeedLazyLoader extends StateNotifier<FeedLazyLoaderState> {
  FeedLazyLoader({int chunkSize = 10})
      : super(FeedLazyLoaderState.initial(chunkSize));

  void syncWithTotal(int totalCount) {
    if (totalCount <= 0) {
      if (state.visibleCount != 0) {
        state = state.copyWith(visibleCount: 0);
      }
      return;
    }
    final desired = max(state.chunkSize, min(state.visibleCount, totalCount));
    final nextVisible = min(desired, totalCount);
    if (nextVisible != state.visibleCount) {
      state = state.copyWith(visibleCount: nextVisible);
    }
  }

  void reset() {
    state = FeedLazyLoaderState.initial(state.chunkSize);
  }

  void extend(int totalCount) {
    if (totalCount <= state.visibleCount) {
      return;
    }
    final next = min(state.visibleCount + state.chunkSize, totalCount);
    if (next != state.visibleCount) {
      state = state.copyWith(visibleCount: next);
    }
  }
}

final feedLazyLoaderProvider =
    StateNotifierProvider.autoDispose.family<FeedLazyLoader, FeedLazyLoaderState, FeedSegment>(
  (ref, segment) {
    return FeedLazyLoader();
  },
);
