import 'package:cringebank/utils/platform_info.dart';
import 'i_notification_service.dart';
import 'null_notification_service.dart';

/// Factory for creating platform-appropriate notification service
class NotificationServiceFactory {
  NotificationServiceFactory._();

  /// Create notification service based on current platform
  static INotificationService create() {
    if (PlatformInfo.supportsLocalNotifications) {
      // Note: Real notification implementation will be added in future
      // Currently using null implementation for all platforms
      return NullNotificationService();
    } else {
      return NullNotificationService();
    }
  }
}
