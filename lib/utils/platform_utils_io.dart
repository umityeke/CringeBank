import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Returns true when running on Windows desktop (non-web), using both
/// dart:io Platform and defaultTargetPlatform for robustness.
bool get isWindowsDesktop =>
    !kIsWeb &&
    (Platform.isWindows || defaultTargetPlatform == TargetPlatform.windows);
