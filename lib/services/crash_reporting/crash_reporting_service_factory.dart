import 'package:cringe_bankasi/utils/platform_info.dart';
import 'i_crash_reporting_service.dart';
import 'firebase_crash_reporting_service.dart';
import 'null_crash_reporting_service.dart';

/// Factory for creating platform-appropriate crash reporting service
class CrashReportingServiceFactory {
  CrashReportingServiceFactory._();

  /// Create crash reporting service based on current platform
  static ICrashReportingService create() {
    if (PlatformInfo.supportsCrashlytics) {
      return FirebaseCrashReportingService();
    } else {
      return NullCrashReportingService();
    }
  }
}
