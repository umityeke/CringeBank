import 'dart:convert';

import 'package:crypto/crypto.dart';

String hashIdentifier(String identifier) {
  final normalized = identifier.trim().toLowerCase();
  final bytes = utf8.encode(normalized);
  final digest = sha256.convert(bytes);
  return digest.toString();
}
