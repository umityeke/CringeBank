import 'package:flutter/material.dart';

/// Responsive breakpoints
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Responsive helper class
class Responsive {
  /// Check if screen width is mobile
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < Breakpoints.mobile;

  /// Check if screen width is tablet
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.mobile &&
      MediaQuery.of(context).size.width < Breakpoints.desktop;

  /// Check if screen width is desktop
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.desktop;

  /// Get screen width
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Get screen height
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Get responsive value based on screen size
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    }
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  /// Get responsive padding
  static EdgeInsets padding(
    BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final padding = value(
      context,
      mobile: mobile ?? 16.0,
      tablet: tablet ?? 24.0,
      desktop: desktop ?? 32.0,
    );
    return EdgeInsets.all(padding);
  }

  /// Get responsive horizontal padding
  static EdgeInsets horizontalPadding(
    BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final padding = value(
      context,
      mobile: mobile ?? 16.0,
      tablet: tablet ?? 24.0,
      desktop: desktop ?? 32.0,
    );
    return EdgeInsets.symmetric(horizontal: padding);
  }

  /// Get responsive vertical padding
  static EdgeInsets verticalPadding(
    BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final padding = value(
      context,
      mobile: mobile ?? 16.0,
      tablet: tablet ?? 24.0,
      desktop: desktop ?? 32.0,
    );
    return EdgeInsets.symmetric(vertical: padding);
  }

  /// Get responsive font size
  static double fontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return value(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.1,
      desktop: desktop ?? mobile * 1.2,
    );
  }

  /// Get max content width for centered layouts
  static double maxContentWidth(BuildContext context) {
    return value(
      context,
      mobile: screenWidth(context),
      tablet: 700,
      desktop: 600,
    );
  }

  /// Build responsive widget
  static Widget builder({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    }
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }
}

/// Extension on BuildContext for easier access
extension ResponsiveContext on BuildContext {
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);
  double get screenWidth => Responsive.screenWidth(this);
  double get screenHeight => Responsive.screenHeight(this);
}
