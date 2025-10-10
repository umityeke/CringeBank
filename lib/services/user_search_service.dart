import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import 'user_service.dart';
import 'telemetry/callable_latency_tracker.dart';

class UserSearchService {
  UserSearchService._();

  static final UserSearchService instance = UserSearchService._();

  static const _usersCollection = 'users';

  static const _popularCacheTtl = Duration(seconds: 60);
  static const _followingCacheTtl = Duration(seconds: 60);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  List<User>? _cachedPopularUsers;
  DateTime? _popularCachedAt;

  final Map<String, _FollowingCacheEntry> _followingCache = {};
  HttpsCallable? _followPreviewCallable;

  Future<List<User>> fetchPopularUsers({int limit = 3}) async {
    final cached = _cachedPopularUsers;
    final cachedAt = _popularCachedAt;
    if (cached != null && cachedAt != null) {
      final age = DateTime.now().difference(cachedAt);
      if (age < _popularCacheTtl && cached.length >= limit) {
        return cached.take(limit).toList(growable: false);
      }
    }

    final query = await _firestore
        .collection(_usersCollection)
        .orderBy('popularityScore', descending: true)
        .limit(limit)
        .get();

    final users = query.docs
        .map((doc) => User.fromMap({...doc.data(), 'id': doc.id}))
        .toList(growable: false);

    _cachedPopularUsers = users;
    _popularCachedAt = DateTime.now();
    return users;
  }

  Future<List<User>> fetchFollowingPreview({int limit = 5}) async {
    final current = UserService.instance.currentUser;
    if (current == null) {
      return const [];
    }

    final cacheKey = current.id;
    final cachedEntry = _followingCache[cacheKey];
    if (cachedEntry != null && !cachedEntry.isExpired(limit)) {
      return cachedEntry.users.take(limit).toList(growable: false);
    }

    final callable = _followPreviewCallable ??= _functions.httpsCallable(
      'getFollowingPreview',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
    );

    try {
      final response =
          await CallableLatencyTracker.run<HttpsCallableResult<dynamic>>(
            functionName: 'getFollowingPreview',
            category: 'userSearch',
            payload: {'limit': limit, 'targetUid': current.id},
            action: () => callable.call(<String, dynamic>{
              'limit': limit,
              'targetUid': current.id,
            }),
          );

      final data = _asMap(response.data);
      final rawItems = _asList(data['items']);
      final users = rawItems
          .map(_asMap)
          .map(_mapPreviewItemToUser)
          .whereType<User>()
          .toList(growable: false);

      _followingCache[cacheKey] = _FollowingCacheEntry(
        users: users,
        fetchedAt: DateTime.now(),
      );

      if (users.length >= limit) {
        return users.take(limit).toList(growable: false);
      }

      return users;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'resource-exhausted') {
        // rate limited - cache empty response briefly to avoid hammering backend
        _followingCache[cacheKey] = _FollowingCacheEntry(
          users: const [],
          fetchedAt: DateTime.now(),
        );
        return const [];
      }
      debugPrint(
        'fetchFollowingPreview failed (${error.code}): ${error.message}',
      );
    } catch (error, stackTrace) {
      debugPrint('fetchFollowingPreview error: $error');
      debugPrint('$stackTrace');
    }

    if (cachedEntry != null) {
      return cachedEntry.users.take(limit).toList(growable: false);
    }

    return const [];
  }

  Future<UserSearchPage> searchByUsernamePrefix({
    required String query,
    int limit = 30,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) {
      return UserSearchPage.empty();
    }

    Query<Map<String, dynamic>> firestoreQuery = _firestore
        .collection(_usersCollection)
        .orderBy('usernameLower')
        .startAt([normalized])
        .endAt(['$normalized\uf8ff'])
        .limit(limit);

    if (startAfter != null) {
      firestoreQuery = firestoreQuery.startAfterDocument(startAfter);
    }

    final snapshot = await firestoreQuery.get();
    final users = snapshot.docs
        .map((doc) => User.fromMap({...doc.data(), 'id': doc.id}))
        .toList(growable: false);

    return UserSearchPage(
      users: users,
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, dynamic val) => MapEntry('$key', val));
  }
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  if (value is List) {
    return value;
  }
  return const [];
}

User? _mapPreviewItemToUser(Map<String, dynamic> item) {
  final uid = _readString(item['uid']);
  if (uid.isEmpty) {
    return null;
  }

  final username = _readString(item['username']);
  final displayNameRaw = _readString(item['displayName']);
  final displayName = displayNameRaw.isNotEmpty ? displayNameRaw : username;
  final avatar = _readString(item['avatar']).isNotEmpty
      ? _readString(item['avatar'])
      : '👤';

  final joinDate = _parseDateTime(item['joinDate']) ?? DateTime.now();
  final lastActive =
      _parseDateTime(item['lastActive']) ??
      _parseDateTime(item['followedAt']) ??
      DateTime.now();

  return User(
    id: uid,
    username: username,
    email: '',
    fullName: displayName,
    displayName: displayName,
    avatar: avatar,
    bio: _readString(item['bio']),
    krepScore: _readInt(item['krepScore']),
    krepLevel: _readInt(item['krepLevel'], fallback: 1),
    followersCount: _readInt(item['followersCount']),
    popularityScore: _readDouble(item['popularityScore']),
    followingCount: _readInt(item['followingCount']),
    entriesCount: _readInt(item['entriesCount']),
    coins: _readInt(item['coins']),
    joinDate: joinDate,
    lastActive: lastActive,
    isPremium: item['isPremium'] == true,
    isVerified: item['verified'] == true,
    isPrivate: item['isPrivate'] == true,
  );
}

String _readString(dynamic value) {
  if (value is String) {
    return value;
  }
  if (value == null) {
    return '';
  }
  return value.toString();
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

double _readDouble(dynamic value, {double fallback = 0}) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is int) {
    // assume milliseconds since epoch
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

class UserSearchPage {
  const UserSearchPage({
    required this.users,
    required this.lastDocument,
    required this.hasMore,
  });

  factory UserSearchPage.empty() =>
      const UserSearchPage(users: [], lastDocument: null, hasMore: false);

  final List<User> users;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class _FollowingCacheEntry {
  _FollowingCacheEntry({required this.users, required this.fetchedAt});

  final List<User> users;
  final DateTime fetchedAt;

  bool isExpired(int limit) {
    return DateTime.now().difference(fetchedAt) >
        UserSearchService._followingCacheTtl;
  }
}
