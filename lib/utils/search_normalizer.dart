import 'dart:math';

/// Arama için metin normalizasyonu ve anahtar kelime üretimi yardımcıları.
class SearchNormalizer {
  static const Map<String, String> _charReplacements = {
    'ğ': 'g',
    'ü': 'u',
    'ş': 's',
    'ı': 'i',
    'i': 'i',
    'ö': 'o',
    'ç': 'c',
    'â': 'a',
    'î': 'i',
    'û': 'u',
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ý': 'y',
    'ÿ': 'y',
  };

  /// Metni aramaya uygun hale getirir (küçük harfe çevir, boşlukları sadeleştir, özel harfleri dönüştür).
  static String normalizeForSearch(String input) {
    if (input.isEmpty) return '';

    final lowered = input.trim().toLowerCase();
    final buffer = StringBuffer();

    for (final rune in lowered.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_charReplacements[char] ?? char);
    }

    final replaced = buffer.toString();
    final sanitized = replaced.replaceAll(RegExp(r'[^a-z0-9@._\s-]'), ' ');
    return sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Kullanıcı belgeleri için arama anahtar kelimelerini üretir.
  static List<String> generateUserSearchKeywords({
    required String fullName,
    required String username,
    required String email,
  }) {
    final keywords = <String>{};

    final normalizedFullName = normalizeForSearch(fullName);
    if (normalizedFullName.isNotEmpty) {
      keywords.add(normalizedFullName);
      final nameTokens = normalizedFullName.split(' ');
      keywords.addAll(nameTokens);

      if (nameTokens.length >= 2) {
        keywords.add('${nameTokens.first} ${nameTokens.last}');
        keywords.add('${nameTokens.first}${nameTokens.last}');
      }
    }

    var normalizedUsername = normalizeForSearch(username);
    normalizedUsername = normalizedUsername.replaceAll(RegExp(r'[@\s]+'), '');
    if (normalizedUsername.isNotEmpty) {
      keywords.add(normalizedUsername);
      keywords.add('@$normalizedUsername');
    }

    final emailLocalPart = email.split('@').first;
    final normalizedEmail = normalizeForSearch(emailLocalPart)
        .replaceAll(RegExp(r'[@\s]+'), '');
    if (normalizedEmail.isNotEmpty) {
      keywords.add(normalizedEmail);
    }

    return keywords
        .map((keyword) => keyword.trim())
        .where((keyword) => keyword.isNotEmpty)
        .take(50)
        .toList(growable: false);
  }

  /// Sorguyu tokenlara böler ve normalize eder.
  static List<String> tokenizeQuery(String query, {int maxTokens = 10}) {
    final normalized = normalizeForSearch(query);
    if (normalized.isEmpty) return [];

    final tokens = normalized.split(' ');
    final set = <String>{};

    for (final token in tokens) {
      if (token.isEmpty) continue;
      set.add(token);
    }

    set.add(normalized);
    final compact = normalized.replaceAll(' ', '');
    if (compact.isNotEmpty) {
      set.add(compact);
    }

    return set.take(max(1, maxTokens)).toList(growable: false);
  }
}
