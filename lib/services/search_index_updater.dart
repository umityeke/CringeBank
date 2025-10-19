import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/cringe_entry.dart';
import '../utils/tag_parser.dart';
import 'telemetry/trace_http_client.dart';

class SearchIndexUpdater {
  SearchIndexUpdater._({
    TraceHttpClient? httpClient,
    String? baseUrl,
    String? apiKey,
  })  : _client = httpClient ?? TraceHttpClient.shared,
        _baseUrl = (baseUrl ?? _envBaseUrl).trim(),
        _apiKey = (apiKey ?? _envApiKey).trim();

  static final SearchIndexUpdater instance = SearchIndexUpdater._();

  static const String _envBaseUrl = String.fromEnvironment(
    'SEARCH_INDEXER_BASE_URL',
    defaultValue: '',
  );
  static const String _envApiKey = String.fromEnvironment(
    'SEARCH_INDEXER_API_KEY',
    defaultValue: '',
  );
  static const Duration _defaultTimeout = Duration(seconds: 8);

  final TraceHttpClient _client;
  final String _baseUrl;
  final String _apiKey;

  bool get isEnabled => _baseUrl.isNotEmpty;

  Future<void> upsertEntry(CringeEntry entry) async {
    final uri = _buildUri('entries');
    if (uri == null) {
      return;
    }

    final sanitized = _sanitizeEntry(entry);
    final hashtags = _collectHashtags(sanitized);
    final mentions = _collectMentions(sanitized);

    final payload = <String, Object?>{
      'operation': 'UPSERT',
      'entity': 'cringe_entry',
      'document': {
        'id': sanitized.id,
        'userId': sanitized.userId,
        'authorHandle': sanitized.authorHandle,
        'authorName': sanitized.authorName,
        'title': sanitized.baslik,
        'description': sanitized.aciklama,
        'category': sanitized.kategori.name,
        'krepLevel': sanitized.krepSeviyesi,
        'isAnonymous': sanitized.isAnonim,
        'type': sanitized.type.value,
        'status': sanitized.status.value,
        'hashtags': hashtags,
        'mentions': mentions,
        'media': sanitized.imageUrls
            .where((url) => url.startsWith('http'))
            .toList(growable: false),
        'createdAt': sanitized.createdAt.toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'source': 'flutter-app',
      },
    };

    try {
      await _client.postJson(
        uri,
        headers: _buildHeaders(),
        jsonBody: payload,
        operation: 'searchIndex.upsertEntry',
        timeout: _defaultTimeout,
      );
    } catch (error, stackTrace) {
      debugPrint('SearchIndexUpdater upsertEntry failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> deleteEntry(
    String entryId, {
    String? ownerId,
    List<String>? hashtags,
  }) async {
    final uri = _buildUri('entries');
    if (uri == null) {
      return;
    }

    final sanitizedTags = <String>{};
    if (hashtags != null) {
      for (final tag in hashtags) {
        final sanitized = TagParser.sanitizeHashtag(tag);
        if (sanitized.isNotEmpty) {
          sanitizedTags.add(sanitized);
        }
      }
    }

    final payload = <String, Object?>{
      'operation': 'DELETE',
      'entity': 'cringe_entry',
      'document': {
        'id': entryId,
        if (ownerId != null && ownerId.isNotEmpty) 'userId': ownerId,
        if (sanitizedTags.isNotEmpty) 'hashtags': sanitizedTags.toList(),
        'source': 'flutter-app',
      },
    };

    try {
      await _client.postJson(
        uri,
        headers: _buildHeaders(),
        jsonBody: payload,
        operation: 'searchIndex.deleteEntry',
        timeout: _defaultTimeout,
      );
    } catch (error, stackTrace) {
      debugPrint('SearchIndexUpdater deleteEntry failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Uri? _buildUri(String path) {
    if (!isEnabled) {
      return null;
    }
    final normalizedBase =
        _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.tryParse('$normalizedBase/$normalizedPath');
  }

  Map<String, String> _buildHeaders() {
    if (_apiKey.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'x-api-key': _apiKey};
  }

  CringeEntry _sanitizeEntry(CringeEntry entry) {
    final sanitizedTags = <String>{};
    for (final tag in entry.etiketler) {
      final normalized = TagParser.sanitizeHashtag(tag);
      if (normalized.isNotEmpty) {
        sanitizedTags.add(normalized);
      }
    }
    return entry.copyWith(etiketler: sanitizedTags.toList(growable: false));
  }

  List<String> _collectHashtags(CringeEntry entry) {
    final tags = <String>{...entry.etiketler};
    tags.addAll(TagParser.extractHashtags(entry.baslik));
    tags.addAll(TagParser.extractHashtags(entry.aciklama));
    tags.removeWhere((tag) => tag.isEmpty);
    return tags.toList(growable: false);
  }

  List<String> _collectMentions(CringeEntry entry) {
    final mentions = <String>{};
    mentions.addAll(TagParser.extractMentions(entry.baslik));
    mentions.addAll(TagParser.extractMentions(entry.aciklama));
    mentions.removeWhere((mention) => mention.isEmpty);
    return mentions.toList(growable: false);
  }
}
