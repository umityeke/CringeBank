import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../screens/simple_profile_screen.dart';
import '../utils/safe_haptics.dart';

/// Opens the profile screen for the provided user identifier with an optional
/// [initialUser] payload. Falls back to the [initialUser.id] when [userId] is
/// not supplied. When [withHaptics] is true a light selection haptic is
/// triggered before navigation.
Future<T?> openUserProfile<T>(
  BuildContext context, {
  String? userId,
  User? initialUser,
  bool useRootNavigator = false,
  bool withHaptics = true,
}) {
  final normalizedId = (userId ?? initialUser?.id ?? '').trim();

  if (withHaptics) {
    SafeHaptics.selection();
  }

  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    MaterialPageRoute(
      builder: (_) => SimpleProfileScreen(
        userId: normalizedId.isNotEmpty ? normalizedId : null,
        initialUser: initialUser,
      ),
    ),
  );
}
