import 'dart:math';

class NormalizedText {
  final String original;
  final String normalizedTr;
  final String ascii;

  const NormalizedText({
    required this.original,
    required this.normalizedTr,
    required this.ascii,
  });

  List<String> tokenize({int maxTokens = 10}) {
    final set = <String>{};
    if (normalizedTr.isNotEmpty) {
      set.addAll(normalizedTr.split(' '));
      set.add(normalizedTr);
      set.add(normalizedTr.replaceAll(' ', ''));
    }
    if (ascii.isNotEmpty) {
      set.addAll(ascii.split(' '));
      set.add(ascii);
      set.add(ascii.replaceAll(' ', ''));
    }
    set.removeWhere((token) => token.isEmpty);
    return set.take(max(maxTokens, 1)).toList(growable: false);
  }
}

/// Arama için metin normalizasyonu ve anahtar kelime üretimi yardımcıları.
class SearchNormalizer {
  static const Map<String, String> _charReplacements = {
    'ğ': 'g',
    'Ğ': 'g',
    'ü': 'u',
    'Ü': 'u',
    'ş': 's',
    'Ş': 's',
    'ı': 'i',
    'I': 'i',
    'İ': 'i',
    'i': 'i',
    'ö': 'o',
    'Ö': 'o',
    'ç': 'c',
    'Ç': 'c',
    'â': 'a',
    'Â': 'a',
    'î': 'i',
    'Î': 'i',
    'û': 'u',
    'Û': 'u',
    'á': 'a',
    'Á': 'a',
    'à': 'a',
    'À': 'a',
    'ä': 'a',
    'Ä': 'a',
    'å': 'a',
    'Å': 'a',
    'é': 'e',
    'É': 'e',
    'è': 'e',
    'È': 'e',
    'ê': 'e',
    'Ê': 'e',
    'ë': 'e',
    'Ë': 'e',
    'ò': 'o',
    'Ò': 'o',
    'ó': 'o',
    'Ó': 'o',
    'ô': 'o',
    'Ô': 'o',
    'õ': 'o',
    'Õ': 'o',
    'ù': 'u',
    'Ù': 'u',
    'ú': 'u',
    'Ú': 'u',
    'ý': 'y',
    'Ý': 'y',
    'ÿ': 'y',
  };

  static String _toTurkishLowercase(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      if (char == 'I') {
        buffer.write('ı');
        continue;
      }
      if (char == 'İ') {
        buffer.write('i');
        continue;
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }

  static String _foldToAscii(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_charReplacements[char] ?? char);
    }
    return buffer.toString();
  }

  static String _sanitize(String input) {
    final sanitized = input.replaceAll(RegExp(r'[^a-z0-9@._\s-]'), ' ');
    return sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static NormalizedText buildNormalization(String input) {
    if (input.isEmpty) {
      return const NormalizedText(
        original: '',
        normalizedTr: '',
        ascii: '',
      );
    }

    final trimmed = input.trim();
    final lowered = _toTurkishLowercase(trimmed);
    final normalizedTr = _sanitize(lowered);
    final ascii = _sanitize(_foldToAscii(lowered));

    return NormalizedText(
      original: input,
      normalizedTr: normalizedTr,
      ascii: ascii,
    );
  }

  /// Metni aramaya uygun hale getirir (küçük harfe çevir, boşlukları sadeleştir, özel harfleri dönüştür).
  static String normalizeForSearch(String input) {
    if (input.isEmpty) return '';

    return buildNormalization(input).ascii;
  }

  /// Kullanıcı belgeleri için arama anahtar kelimelerini üretir.
  static List<String> generateUserSearchKeywords({
    required String fullName,
    required String username,
    required String email,
  }) {
    final keywords = <String>{};

  final normalizedFullName = buildNormalization(fullName).ascii;
    if (normalizedFullName.isNotEmpty) {
      keywords.add(normalizedFullName);
      final nameTokens = normalizedFullName.split(' ');
      keywords.addAll(nameTokens);

      if (nameTokens.length >= 2) {
        keywords.add('${nameTokens.first} ${nameTokens.last}');
        keywords.add('${nameTokens.first}${nameTokens.last}');
      }
    }

  var normalizedUsername = buildNormalization(username).ascii;
    normalizedUsername = normalizedUsername.replaceAll(RegExp(r'[@\s]+'), '');
    if (normalizedUsername.isNotEmpty) {
      keywords.add(normalizedUsername);
      keywords.add('@$normalizedUsername');
    }

    final emailLocalPart = email.split('@').first;
  final normalizedEmail = buildNormalization(emailLocalPart).ascii
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
    final normalized = buildNormalization(query);
    final tokens = <String>{};

    tokens.addAll(normalized.tokenize(maxTokens: maxTokens));

    if (normalized.normalizedTr.isNotEmpty) {
      tokens.addAll(normalized.normalizedTr.split(' '));
    }
    if (normalized.ascii.isNotEmpty) {
      tokens.addAll(normalized.ascii.split(' '));
    }

    tokens.removeWhere((token) => token.isEmpty);

    return tokens.take(max(1, maxTokens)).toList(growable: false);
  }
}
