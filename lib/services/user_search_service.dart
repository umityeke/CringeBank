import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import 'user_service.dart';

class UserSearchService {
  UserSearchService._();

  static final UserSearchService instance = UserSearchService._();

  static const _usersCollection = 'users';
  static const _followsCollection = 'follows';

  static const _popularCacheTtl = Duration(seconds: 60);
  static const _followingCacheTtl = Duration(seconds: 60);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<User>? _cachedPopularUsers;
  DateTime? _popularCachedAt;

  final Map<String, _FollowingCacheEntry> _followingCache = {};

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

    final followSnapshot = await _firestore
        .collection(_followsCollection)
        .where('followerId', isEqualTo: current.id)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    if (followSnapshot.docs.isEmpty) {
      _followingCache[cacheKey] = _FollowingCacheEntry(
        users: const [],
        fetchedAt: DateTime.now(),
      );
      return const [];
    }

    final followedIds = followSnapshot.docs
        .map((doc) => (doc.data()['followedId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    if (followedIds.isEmpty) {
      _followingCache[cacheKey] = _FollowingCacheEntry(
        users: const [],
        fetchedAt: DateTime.now(),
      );
      return const [];
    }

    final futures = followedIds
        .map((id) async {
          final doc = await _firestore
              .collection(_usersCollection)
              .doc(id)
              .get();
          if (!doc.exists) {
            return null;
          }
          return User.fromMap({...doc.data()!, 'id': doc.id});
        })
        .toList(growable: false);

    final results = await Future.wait(futures);
    final users = results.whereType<User>().toList(growable: false);

    _followingCache[cacheKey] = _FollowingCacheEntry(
      users: users,
      fetchedAt: DateTime.now(),
    );

    return users;
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
        .orderBy('username_lc')
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
