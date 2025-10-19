import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models/feed_entry.dart';
import '../domain/models/feed_segment.dart';
import '../domain/models/sponsor_campaign.dart';
import 'feed_api_config.dart';
import '../../../services/telemetry/callable_latency_tracker.dart';

class RemoteFeedRepository {
  RemoteFeedRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    required FeedApiConfig config,
    DateTime Function()? now,
    Random? random,
  }) : _firestoreInstance = firestore,
       _functionsInstance = functions,
       _config = config,
       _now = now ?? DateTime.now,
       _random = random ?? Random();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFunctions? _functionsInstance;
  final FeedApiConfig _config;
  final DateTime Function() _now;
  final Random _random;
  final DateFormat _dateLabelFormatter = DateFormat('d MMM', 'tr_TR');

  FirebaseFirestore _firestore() {
    if (_firestoreInstance != null) {
      return _firestoreInstance!;
    }
    try {
      _firestoreInstance = FirebaseFirestore.instance;
    } catch (error, stackTrace) {
      debugPrint('Remote feed Firestore unavailable: $error');
      debugPrint('$stackTrace');
      throw StateError('Firestore is not initialized');
    }
    return _firestoreInstance!;
  }

  FirebaseFunctions _functions() {
    if (_functionsInstance != null) {
      return _functionsInstance!;
    }
    try {
      _functionsInstance = FirebaseFunctions.instanceFor(
        region: _config.region,
      );
    } catch (error, stackTrace) {
      debugPrint('Remote feed Functions unavailable: $error');
      debugPrint('$stackTrace');
      throw StateError('Cloud Functions is not initialized');
    }
    return _functionsInstance!;
  }

  Stream<List<FeedEntry>> watchFollowingFeed(String userId) {
    final firestore = _firestore();
    CollectionReference<Map<String, dynamic>> collection = firestore
        .collection(_config.followingCollection)
        .doc(userId)
        .collection(_config.followingEntriesSubcollection);

    Query<Map<String, dynamic>> query = collection.limit(_config.pageSize);
    if (_config.followingOrderField.isNotEmpty) {
      query = query.orderBy(_config.followingOrderField, descending: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => _mapFeedEntry(
              _normalize(doc.data()),
              id: doc.id,
              segment: FeedSegment.following,
            ),
          )
          .toList(growable: false);
    });
  }

  Future<List<FeedEntry>> fetchRecommendedFeed(String userId) async {
    final functions = _functions();
    final response = await functions.callWithLatency<Map<String, dynamic>>(
      _config.recommendedCallable,
      category: _config.recommendedCategory,
      payload: <String, dynamic>{
        'limit': _config.pageSize,
        'includeRead': false,
        'includeHidden': false,
      },
    );

    final payload = _normalize(response.data);
    final events = payload['events'];
    if (events is! List) {
      return const <FeedEntry>[];
    }

    final results = <FeedEntry>[];
    final seenIds = <String>{};

    for (final event in events) {
      if (event is! Map) {
        continue;
      }
      final normalized = _normalize(event);
      final entry = _mapFeedEntry(normalized, segment: FeedSegment.recommended);
      if (seenIds.add(entry.id)) {
        results.add(entry);
      }
    }

    return results;
  }

  Stream<List<SponsorCampaign>> watchSponsorCampaigns(String userId) {
    assert(userId.isNotEmpty, 'userId boş olamaz');
    final firestore = _firestore();
    final query = firestore
        .collection(_config.sponsorCollection)
        .orderBy('priority', descending: true)
        .limit(12);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => _mapSponsorCampaign(doc.id, _normalize(doc.data())))
          .toList(growable: false);
    });
  }

  FeedEntry _mapFeedEntry(
    Map<String, dynamic> data, {
    FeedSegment segment = FeedSegment.following,
    String? id,
  }) {
    final rawEntryId =
        (id ??
                _pickString(data, [
                  ['eventPublicId'],
                  ['entryId'],
                  ['metadata', 'entryId'],
                  ['metadata', 'entry', 'id'],
                  ['id'],
                ]))
            .trim();
    final entryId = rawEntryId.isEmpty ? _randomId() : rawEntryId;

    final author = _pickString(data, [
      ['author'],
      ['authorName'],
      ['authorDisplayName'],
      ['actorDisplayName'],
      ['metadata', 'author', 'displayName'],
      ['metadata', 'actor', 'displayName'],
      ['metadata', 'entry', 'authorName'],
      ['metadata', 'entry', 'authorDisplayName'],
    ], fallback: 'Anonim Kullanıcı');

    final title = _pickString(data, [
      ['title'],
      ['headline'],
      ['metadata', 'title'],
      ['metadata', 'headline'],
      ['metadata', 'entry', 'title'],
      ['metadata', 'content', 'title'],
      ['metadata', 'post', 'title'],
    ], fallback: 'Yeni paylaşım');

    var excerpt = _pickString(data, [
      ['excerpt'],
      ['summary'],
      ['metadata', 'excerpt'],
      ['metadata', 'summary'],
      ['metadata', 'entry', 'excerpt'],
      ['metadata', 'entry', 'body'],
      ['metadata', 'content', 'excerpt'],
      ['metadata', 'content', 'text'],
      ['metadata', 'post', 'excerpt'],
      ['body'],
      ['text'],
    ], fallback: '');

    if (excerpt.isEmpty) {
      excerpt = title;
    }

    final tag = _pickString(data, [
      ['tag'],
      ['metadata', 'tag'],
      ['metadata', 'topic'],
      ['metadata', 'entry', 'tag'],
      ['metadata', 'entry', 'topic'],
      ['metadata', 'category'],
      ['metadata', 'entry', 'category'],
    ], fallback: segment == FeedSegment.following ? 'Takip' : 'Öneri');

    final likeCount = _pickInt(data, [
      ['likeCount'],
      ['likes'],
      ['metadata', 'likeCount'],
      ['metadata', 'likes'],
      ['metadata', 'entry', 'likeCount'],
      ['metadata', 'stats', 'likeCount'],
      ['metadata', 'stats', 'likes'],
      ['metadata', 'metrics', 'likes'],
    ]);

    final commentCount = _pickInt(data, [
      ['commentCount'],
      ['comments'],
      ['metadata', 'commentCount'],
      ['metadata', 'comments'],
      ['metadata', 'entry', 'commentCount'],
      ['metadata', 'stats', 'commentCount'],
      ['metadata', 'metrics', 'commentCount'],
    ]);

    final accentColor =
        _pickColor(data, [
          ['accentColor'],
          ['metadata', 'accentColor'],
          ['metadata', 'entry', 'accentColor'],
          ['metadata', 'theme', 'accentColor'],
        ]) ??
        _fallbackAccent();

    final avatarUrl = _pickString(data, [
      ['avatarUrl'],
      ['metadata', 'avatarUrl'],
      ['metadata', 'author', 'avatarUrl'],
      ['metadata', 'author', 'photoUrl'],
      ['metadata', 'entry', 'authorAvatarUrl'],
      ['metadata', 'actorAvatarUrl'],
    ]);

    final mediaUrl = _pickString(data, [
      ['mediaUrl'],
      ['metadata', 'mediaUrl'],
      ['metadata', 'entry', 'mediaUrl'],
      ['metadata', 'content', 'mediaUrl'],
      ['metadata', 'media', 'url'],
      ['metadata', 'coverImage'],
    ]);

    final publishedAt = _pickTimestamp(data, [
      ['publishedAt'],
      ['metadata', 'publishedAt'],
      ['metadata', 'entry', 'publishedAt'],
      ['metadata', 'entry', 'createdAt'],
      ['metadata', 'content', 'publishedAt'],
      ['metadata', 'post', 'createdAt'],
      ['metadata', 'createdAt'],
      ['createdAt'],
    ]);

    final relativeLabel = publishedAt != null
        ? _formatRelativeTime(publishedAt)
        : _pickString(data, [
            ['relativeTime'],
            ['metadata', 'relativeTime'],
            ['metadata', 'entry', 'relativeTime'],
          ], fallback: 'şimdi');

    final baseScore = _pickDouble(data, [
      ['score'],
      ['rankingScore'],
      ['metadata', 'rankingScore'],
      ['metadata', 'scores', 'final'],
      ['metadata', 'score'],
    ]);

    final affinityScore = _pickDouble(data, [
      ['metadata', 'affinityScore'],
      ['metadata', 'scores', 'affinity'],
      ['metadata', 'signals', 'affinity'],
    ]);

    final freshnessScore = _pickDouble(data, [
      ['metadata', 'freshnessScore'],
      ['metadata', 'scores', 'freshness'],
      ['metadata', 'signals', 'freshness'],
    ]);

    final diversityWeight = _pickDouble(data, [
      ['metadata', 'diversityWeight'],
      ['metadata', 'scores', 'diversityWeight'],
      ['metadata', 'signals', 'diversityWeight'],
    ]);

    final reasons = _pickStringList(data, [
      ['metadata', 'reasons'],
      ['metadata', 'rankingReasons'],
      ['metadata', 'signals', 'reasons'],
    ]);

    final strategy = _pickString(data, [
      ['metadata', 'strategy'],
      ['metadata', 'rankingStrategy'],
      ['metadata', 'source'],
    ], fallback: segment.name);

    return FeedEntry(
      id: entryId,
      author: author,
      title: title,
      excerpt: excerpt,
      relativeTime: relativeLabel,
      tag: tag,
      likeCount: likeCount,
      commentCount: commentCount,
      accentColor: accentColor,
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
      mediaUrl: mediaUrl.isEmpty ? null : mediaUrl,
      publishedAt: publishedAt,
      baseScore: baseScore,
      affinityScore: affinityScore,
      freshnessScore: freshnessScore,
      diversityWeight: diversityWeight == 0 ? null : diversityWeight,
      rankingReasons: reasons,
      rankingStrategy: strategy,
    );
  }

  SponsorCampaign _mapSponsorCampaign(String id, Map<String, dynamic> data) {
    Color parseColor(List<List<String>> paths, {Color? fallback}) {
      return _pickColor(data, paths) ?? fallback ?? _fallbackAccent();
    }

    final title = _pickString(data, [
      ['title'],
      ['metadata', 'title'],
    ], fallback: 'Sponsor');
    final description = _pickString(data, [
      ['description'],
      ['metadata', 'description'],
    ]);
    final ctaText = _pickString(data, [
      ['ctaText'],
      ['metadata', 'ctaText'],
    ], fallback: 'Göz at');
    final targetUrl = _pickString(data, [
      ['targetUrl'],
      ['metadata', 'targetUrl'],
    ], fallback: '');

    return SponsorCampaign(
      id: id,
      title: title,
      description: description,
      ctaText: ctaText,
      startColor: parseColor([
        ['startColor'],
        ['metadata', 'startColor'],
      ]),
      endColor: parseColor(
        [
          ['endColor'],
          ['metadata', 'endColor'],
        ],
        fallback: parseColor([
          ['startColor'],
          ['metadata', 'startColor'],
        ]),
      ),
      targetUrl: targetUrl.isEmpty ? null : targetUrl,
    );
  }

  Map<String, dynamic> _normalize(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, dynamic v) {
        result[key.toString()] = v;
      });
      return result;
    }
    return <String, dynamic>{};
  }

  String _pickString(
    Map<String, dynamic> data,
    List<List<String>> paths, {
    String fallback = '',
  }) {
    for (final path in paths) {
      final value = _valueFromPath(data, path);
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    for (final path in paths) {
      final value = _valueFromPath(data, path);
      if (value != null) {
        if (value is num) {
          return value.toString();
        }
        if (value is bool) {
          return value ? '1' : '0';
        }
      }
    }
    return fallback;
  }

  int _pickInt(Map<String, dynamic> data, List<List<String>> paths) {
    for (final path in paths) {
      final value = _valueFromPath(data, path);
      final parsed = _asInt(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }

  double? _pickDouble(Map<String, dynamic> data, List<List<String>> paths) {
    for (final path in paths) {
      final value = _valueFromPath(data, path);
      final parsed = _asDouble(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  Color? _pickColor(Map<String, dynamic> data, List<List<String>> paths) {
    for (final path in paths) {
      final value = _valueFromPath(data, path);
      final color = _parseColor(value);
      if (color != null) {
        return color;
      }
    }
    return null;
  }

  List<String> _pickStringList(
    Map<String, dynamic> data,
    List<List<String>> paths,
  ) {
    for (final path in paths) {
      final value = _valueFromPath(data, path);
      final list = _asStringList(value);
      if (list != null && list.isNotEmpty) {
        return list;
      }
    }
    return const <String>[];
  }

  DateTime? _pickTimestamp(
    Map<String, dynamic> data,
    List<List<String>> paths,
  ) {
    for (final path in paths) {
      final value = _valueFromPath(data, path);
      final parsed = _parseTimestamp(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  dynamic _valueFromPath(Map<String, dynamic> root, List<String> path) {
    dynamic current = root;
    for (final segment in path) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
      } else if (current is Map) {
        current = _normalize(current)[segment];
      } else {
        return null;
      }
    }
    return current;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final sanitized = value.trim();
      if (sanitized.isEmpty) {
        return null;
      }
      return int.tryParse(sanitized);
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final sanitized = value.trim();
      if (sanitized.isEmpty) {
        return null;
      }
      return double.tryParse(sanitized);
    }
    return null;
  }

  Color? _parseColor(dynamic value) {
    if (value is int) {
      if (value <= 0xFFFFFF) {
        return Color(0xFF000000 | value);
      }
      return Color(value);
    }

    if (value is String) {
      final input = value.trim().toLowerCase();
      if (input.isEmpty) {
        return null;
      }
      if (input.startsWith('#')) {
        final hex = input.substring(1);
        return _colorFromHex(hex);
      }
      if (input.startsWith('0x')) {
        final hex = input.substring(2);
        return _colorFromHex(hex);
      }
      if (input.startsWith('rgb')) {
        final match = RegExp(r'rgb\s*\(([^)]+)\)').firstMatch(input);
        if (match != null) {
          final parts = match
              .group(1)!
              .split(',')
              .map((part) => part.trim())
              .toList();
          if (parts.length >= 3) {
            final r = int.tryParse(parts[0]) ?? 0;
            final g = int.tryParse(parts[1]) ?? 0;
            final b = int.tryParse(parts[2]) ?? 0;
            return Color.fromARGB(
              0xFF,
              r.clamp(0, 255),
              g.clamp(0, 255),
              b.clamp(0, 255),
            );
          }
        }
      }
    }

    if (value is List && value.length >= 3) {
      final r = _asInt(value[0]) ?? 0;
      final g = _asInt(value[1]) ?? 0;
      final b = _asInt(value[2]) ?? 0;
      return Color.fromARGB(
        0xFF,
        r.clamp(0, 255),
        g.clamp(0, 255),
        b.clamp(0, 255),
      );
    }

    if (value is Map) {
      final map = _normalize(value);
      final r = _asInt(map['r']);
      final g = _asInt(map['g']);
      final b = _asInt(map['b']);
      if (r != null && g != null && b != null) {
        return Color.fromARGB(
          0xFF,
          r.clamp(0, 255),
          g.clamp(0, 255),
          b.clamp(0, 255),
        );
      }
      final hex = map['hex'] ?? map['value'];
      if (hex is String) {
        return _colorFromHex(hex);
      }
    }

    return null;
  }

  List<String>? _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item == null ? '' : item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String) {
      final sanitized = value.trim();
      if (sanitized.isEmpty) {
        return null;
      }
      return sanitized
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return null;
  }

  Color? _colorFromHex(String hex) {
    final normalized = hex.replaceAll('#', '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    final buffer = StringBuffer();
    if (normalized.length == 6) {
      buffer.write('ff');
    }
    buffer.write(normalized);
    final value = int.tryParse(buffer.toString(), radix: 16);
    if (value == null) {
      return null;
    }
    return Color(value);
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
      if (value > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
      }
    }
    if (value is double) {
      final millis = (value >= 1000000000000)
          ? value.toInt()
          : (value * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    if (value is String) {
      if (value.trim().isEmpty) {
        return null;
      }
      final parsed = DateTime.tryParse(value);
      return parsed?.toUtc();
    }
    if (value is Map) {
      final map = _normalize(value);
      final seconds = _asInt(map['seconds']);
      final nanos = _asInt(map['nanoseconds']) ?? 0;
      if (seconds != null) {
        final millis = (seconds * 1000) + (nanos / 1e6).round();
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      }
      final milliseconds = _asInt(map['milliseconds']) ?? _asInt(map['ms']);
      if (milliseconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
      }
    }
    return null;
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = _now().toUtc();
    final target = timestamp.toUtc();
    var difference = now.difference(target);
    if (difference.isNegative) {
      difference = -difference;
    }

    if (difference.inSeconds < 60) {
      return 'şimdi';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dk';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} sa';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} g';
    }
    return _dateLabelFormatter.format(target.toLocal());
  }

  Color _fallbackAccent() {
    final seed = _random.nextInt(0xFFFFFF);
    return Color(0xFF000000 | seed);
  }

  String _randomId() =>
      'entry-${_now().millisecondsSinceEpoch}-${_random.nextInt(9999)}';
}
