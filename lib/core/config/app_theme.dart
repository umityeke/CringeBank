import 'package:flutter/material.dart';

import '../../shared/theme/cg_theme.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => CgTheme.light();

  static ThemeData get dark => CgTheme.dark();
}
