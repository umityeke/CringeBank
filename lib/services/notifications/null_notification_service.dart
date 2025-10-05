import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/cringe_entry.dart';
import 'i_notification_service.dart';

/// Null implementation of notification service
///
/// Used on platforms that don't support local notifications (Web, Windows, Linux)
/// Provides a safe no-op implementation.
class NullNotificationService implements INotificationService {
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    debugPrint('„️ Local notifications not available on this platform');
    _isInitialized = true;
  }

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<bool> areNotificationsEnabled() async => false;

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
  }) async {
    debugPrint('ğ“ Notification (not shown): $title - $body');
  }

  @override
  Future<void> cancelNotification(int id) async {
    // No-op
  }

  @override
  Future<void> cancelAllNotifications() async {
    // No-op
  }

  @override
  Future<void> showCringeRadarNotification({
    required CringeEntry entry,
    required double distance,
  }) async {
    debugPrint(
      'ğ” Cringe Radar (not shown): ${entry.title} at ${distance.toStringAsFixed(0)}m',
    );
  }

  @override
  Future<void> showDailyMotivation() async {
    debugPrint('?Ÿ’– Daily Motivation (not shown)');
  }

  @override
  Future<void> showCompetitionNotification({
    required String title,
    required String message,
  }) async {
    debugPrint('ğ† Competition (not shown): $title - $message');
  }

  @override
  Future<void> showTherapyReminder() async {
    debugPrint('ğ Therapy Reminder (not shown)');
  }

  @override
  void startCringeRadar() {
    debugPrint('ğ” Cringe Radar: Not available on this platform');
  }

  @override
  void stopCringeRadar() {
    // No-op
  }

  @override
  void startDailyMotivation() {
    debugPrint('?Ÿ’– Daily Motivation: Not available on this platform');
  }

  @override
  void stopDailyMotivation() {
    // No-op
  }

  @override
  void dispose() {
    // No-op
  }
}
