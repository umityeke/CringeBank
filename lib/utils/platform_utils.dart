// Cross-platform platform utilities with conditional exports.
// This file provides safe helpers that can be used from web/desktop/mobile
// without importing dart:io directly in shared code.

export 'platform_utils_io.dart'
    if (dart.library.html) 'platform_utils_web.dart';
