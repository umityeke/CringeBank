import 'dart:math';

class UsernamePolicies {
  UsernamePolicies._();

  static const int minLength = 3;
  static const int maxLength = 24;
  static final RegExp _allowedPattern = RegExp(r'^[a-z0-9_]+$');
  static final Set<String> _reservedUsernames = <String>{
    'admin',
    'moderator',
    'support',
    'help',
    'root',
    'system',
    'superadmin',
    'null',
    'undefined',
  };

  static UsernameValidationResult validate(String input) {
    final normalized = normalize(input);
    final issues = <UsernameValidationIssue>[];

    if (normalized.isEmpty) {
      issues.add(UsernameValidationIssue.empty);
      return UsernameValidationResult(normalized: normalized, issues: issues);
    }

    if (normalized.length < minLength) {
      issues.add(UsernameValidationIssue.tooShort);
    }

    if (normalized.length > maxLength) {
      issues.add(UsernameValidationIssue.tooLong);
    }

    if (!_allowedPattern.hasMatch(normalized)) {
      issues.add(UsernameValidationIssue.invalidCharacters);
    }

    if (normalized.startsWith('_') || normalized.endsWith('_')) {
      issues.add(UsernameValidationIssue.leadingOrTrailingUnderscore);
    }

    if (normalized.contains('__')) {
      issues.add(UsernameValidationIssue.consecutiveUnderscore);
    }

    if (_reservedUsernames.contains(normalized)) {
      issues.add(UsernameValidationIssue.reserved);
    }

    return UsernameValidationResult(normalized: normalized, issues: issues);
  }

  static String normalize(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
  }

  static List<String> issueMessages(UsernameValidationResult result) {
    return result.issues
        .map(
          (issue) => switch (issue) {
            UsernameValidationIssue.empty => 'Kullanıcı adı boş olamaz.',
            UsernameValidationIssue.tooShort =>
              'Kullanıcı adı en az $minLength karakter olmalıdır.',
            UsernameValidationIssue.tooLong =>
              'Kullanıcı adı en fazla $maxLength karakter olabilir.',
            UsernameValidationIssue.invalidCharacters =>
              'Sadece küçük harf, sayı ve alt çizgi kullanabilirsin.',
            UsernameValidationIssue.leadingOrTrailingUnderscore =>
              'Kullanıcı adı alt çizgi ile başlayamaz veya bitebilir.',
            UsernameValidationIssue.consecutiveUnderscore =>
              'Birden fazla ardışık alt çizgi kullanamazsın.',
            UsernameValidationIssue.reserved =>
              'Bu kullanıcı adı CringeBank tarafından rezerve edilmiştir.',
          },
        )
        .toList(growable: false);
  }

  static String formatCooldown(Duration duration) {
    if (duration.inSeconds <= 0) {
      return 'şimdi';
    }

    final parts = <String>[];
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);

    if (days > 0) {
      parts.add('$days gün');
    }
    if (hours > 0) {
      parts.add('$hours saat');
    }
    if (minutes > 0 && parts.length < 2) {
      parts.add('$minutes dakika');
    }

    if (parts.isEmpty) {
      final seconds = max(duration.inSeconds, 1);
      parts.add('$seconds saniye');
    }

    return parts.take(2).join(' ');
  }
}

class UsernameValidationResult {
  UsernameValidationResult({required this.normalized, required this.issues});

  final String normalized;
  final List<UsernameValidationIssue> issues;

  bool get isValid => issues.isEmpty;
}

enum UsernameValidationIssue {
  empty,
  tooShort,
  tooLong,
  invalidCharacters,
  leadingOrTrailingUnderscore,
  consecutiveUnderscore,
  reserved,
}

class DisplayNamePolicies {
  DisplayNamePolicies._();

  static const int minLength = 3;
  static const int maxLength = 40;
  static final RegExp _allowedPattern = RegExp(
    r"^[\p{L}0-9][\p{L}0-9 ._'’-]{1,}$",
    unicode: true,
  );

  static DisplayNameValidationResult validate(String input) {
    final normalized = normalize(input);
    final issues = <DisplayNameValidationIssue>[];

    if (normalized.isEmpty) {
      issues.add(DisplayNameValidationIssue.empty);
      return DisplayNameValidationResult(
        normalized: normalized,
        issues: issues,
      );
    }

    if (normalized.length < minLength) {
      issues.add(DisplayNameValidationIssue.tooShort);
    }

    if (normalized.length > maxLength) {
      issues.add(DisplayNameValidationIssue.tooLong);
    }

    if (!_allowedPattern.hasMatch(normalized)) {
      issues.add(DisplayNameValidationIssue.invalidCharacters);
    }

    return DisplayNameValidationResult(normalized: normalized, issues: issues);
  }

  static String normalize(String input) {
    return input.trim().replaceAll(RegExp(r'\s{2,}'), ' ');
  }

  static List<String> issueMessages(DisplayNameValidationResult result) {
    return result.issues
        .map(
          (issue) => switch (issue) {
            DisplayNameValidationIssue.empty => 'İsim alanı boş olamaz.',
            DisplayNameValidationIssue.tooShort =>
              'İsim en az $minLength karakter içermelidir.',
            DisplayNameValidationIssue.tooLong =>
              'İsim en fazla $maxLength karakter olabilir.',
            DisplayNameValidationIssue.invalidCharacters =>
              'Harf, rakam ve . _ \' - gibi temel işaretler kullanılabilir.',
          },
        )
        .toList(growable: false);
  }
}

class DisplayNameValidationResult {
  DisplayNameValidationResult({required this.normalized, required this.issues});

  final String normalized;
  final List<DisplayNameValidationIssue> issues;

  bool get isValid => issues.isEmpty;
}

enum DisplayNameValidationIssue { empty, tooShort, tooLong, invalidCharacters }
