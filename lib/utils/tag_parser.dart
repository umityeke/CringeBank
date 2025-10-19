import 'search_normalizer.dart';

/// Utility helpers to extract and sanitize hashtags and @mentions
/// from free-form text inputs like captions or comments.
class TagParser {
  TagParser._();

  static final RegExp _hashtagPattern = RegExp(
    r'(?<!\w)#([a-zA-Z0-9_ğüşiöçĞÜŞİÖÇ]{2,64})',
    unicode: true,
  );

  static final RegExp _mentionPattern = RegExp(
    r'(?<!\w)@([a-zA-Z0-9_.]{2,32})',
    unicode: true,
  );

  static List<String> extractHashtags(String text) {
    if (text.isEmpty) {
      return const <String>[];
    }
    final results = <String>{};
    for (final match in _hashtagPattern.allMatches(text)) {
      final candidate = match.group(1) ?? '';
      final sanitized = sanitizeHashtag(candidate);
      if (sanitized.length >= 2) {
        results.add(sanitized);
      }
    }
    return results.toList(growable: false);
  }

  static List<String> extractMentions(String text) {
    if (text.isEmpty) {
      return const <String>[];
    }
    final results = <String>{};
    for (final match in _mentionPattern.allMatches(text)) {
      final candidate = match.group(1) ?? '';
      final sanitized = sanitizeMention(candidate);
      if (sanitized.length >= 2) {
        results.add(sanitized);
      }
    }
    return results.toList(growable: false);
  }

  static String sanitizeHashtag(String raw) {
    if (raw.isEmpty) {
      return '';
    }
    var value = raw.trim();
    if (value.startsWith('#')) {
      value = value.substring(1);
    }
    value = value.replaceAll(RegExp(r'\s+'), '');
    if (value.isEmpty) {
      return '';
    }
    final normalized = SearchNormalizer.normalizeForSearch(value);
    return normalized.replaceAll(RegExp(r'[^a-z0-9_]+'), '');
  }

  static String sanitizeMention(String raw) {
    if (raw.isEmpty) {
      return '';
    }
    var value = raw.trim();
    if (value.startsWith('@')) {
      value = value.substring(1);
    }
    value = value.replaceAll(RegExp(r'\s+'), '');
    if (value.isEmpty) {
      return '';
    }
    final normalized = SearchNormalizer.normalizeForSearch(value);
    return normalized.replaceAll(RegExp(r'[^a-z0-9_.]+'), '');
  }
}
