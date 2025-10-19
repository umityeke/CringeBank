import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class NavigationState {
  const NavigationState({
    required this.selectedIndex,
    required this.previousIndex,
  });

  const NavigationState.initial() : selectedIndex = 0, previousIndex = 0;

  final int selectedIndex;
  final int previousIndex;

  NavigationState copyWith({int? selectedIndex, int? previousIndex}) {
    return NavigationState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      previousIndex: previousIndex ?? this.previousIndex,
    );
  }
}

class NavigationController extends StateNotifier<NavigationState> {
  NavigationController() : super(const NavigationState.initial());

  void select(int index) {
    if (index == state.selectedIndex) {
      return;
    }
    state = state.copyWith(
      previousIndex: state.selectedIndex,
      selectedIndex: index,
    );
  }

  void restorePrevious() {
    state = state.copyWith(selectedIndex: state.previousIndex);
  }

  void resetToHome() {
    state = state.copyWith(previousIndex: 0, selectedIndex: 0);
  }
}

final navigationControllerProvider =
    StateNotifierProvider<NavigationController, NavigationState>(
      (ref) => NavigationController(),
    );
