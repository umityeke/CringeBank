import 'dart:async';
import '../../models/cringe_entry.dart';

/// Abstract interface for notification services
///
/// Provides a platform-agnostic API for local notifications.
abstract class INotificationService {
  /// Initialize the notification service
  Future<void> initialize();

  /// Check if notifications are initialized
  bool get isInitialized;

  /// Request notification permissions
  Future<bool> requestPermissions();

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled();

  /// Show a notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
  });

  /// Cancel a specific notification
  Future<void> cancelNotification(int id);

  /// Cancel all notifications
  Future<void> cancelAllNotifications();

  // ============================================================================
  // CRINGE-SPECIFIC FEATURES
  // ============================================================================

  /// Show cringe radar notification
  Future<void> showCringeRadarNotification({
    required CringeEntry entry,
    required double distance,
  });

  /// Show daily motivation notification
  Future<void> showDailyMotivation();

  /// Show competition notification
  Future<void> showCompetitionNotification({
    required String title,
    required String message,
  });

  /// Show therapy reminder notification
  Future<void> showTherapyReminder();

  /// Start cringe radar (periodic location-based notifications)
  void startCringeRadar();

  /// Stop cringe radar
  void stopCringeRadar();

  /// Start daily motivation (periodic motivational messages)
  void startDailyMotivation();

  /// Stop daily motivation
  void stopDailyMotivation();

  /// Dispose and cleanup resources
  void dispose();
}
