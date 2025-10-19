import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

import '../models/user_model.dart' as models;
import 'user_service.dart';

class TaggingPolicy {
  const TaggingPolicy({
    required this.bannedHashtags,
    required this.blockedUsernames,
    required this.blockedUserIds,
    required this.refreshedAt,
  });

  const TaggingPolicy.empty()
    : bannedHashtags = const <String>{},
      blockedUsernames = const <String>{},
      blockedUserIds = const <String>{},
      refreshedAt = null;

  final Set<String> bannedHashtags;
  final Set<String> blockedUsernames;
  final Set<String> blockedUserIds;
  final DateTime? refreshedAt;

  bool get hasRestrictions =>
      bannedHashtags.isNotEmpty ||
      blockedUsernames.isNotEmpty ||
      blockedUserIds.isNotEmpty;
}

class TaggingPolicyService {
  TaggingPolicyService._({
    FirebaseFirestore? firestore,
    firebase_auth.FirebaseAuth? auth,
    TaggingPolicy? cachedPolicy,
    DateTime? cachedAt,
    Duration? cacheTtl,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? firebase_auth.FirebaseAuth.instance,
       _cachedPolicy = cachedPolicy,
       _cachedAt = cachedAt,
       _cacheTtl = cacheTtl ?? const Duration(minutes: 5);

  static TaggingPolicyService instance = TaggingPolicyService._();

  final FirebaseFirestore _firestore;
  final firebase_auth.FirebaseAuth _auth;

  TaggingPolicy? _cachedPolicy;
  DateTime? _cachedAt;
  final Duration _cacheTtl;

  @visibleForTesting
  static void configureForTesting({
    FirebaseFirestore? firestore,
    firebase_auth.FirebaseAuth? auth,
    TaggingPolicy? cachedPolicy,
    DateTime? cachedAt,
    Duration? cacheTtl,
  }) {
    instance = TaggingPolicyService._(
      firestore: firestore,
      auth: auth,
      cachedPolicy: cachedPolicy,
      cachedAt: cachedAt,
      cacheTtl: cacheTtl,
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    instance = TaggingPolicyService._();
  }

  Future<TaggingPolicy> fetchPolicy({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final cachedPolicy = _cachedPolicy;
    final cachedAt = _cachedAt;
    if (!forceRefresh && cachedPolicy != null && cachedAt != null) {
      final age = now.difference(cachedAt);
      if (age < _cacheTtl) {
        return _cachedPolicy!;
      }
    }

    final uid = _auth.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      final fallback = const TaggingPolicy.empty();
      _cachedPolicy = fallback;
      _cachedAt = now;
      return fallback;
    }

    try {
      final blockedIds = await _loadBlockedIds(uid);
      final blockedHandles = await _resolveUsernames(
        blockedIds,
        timeout: const Duration(seconds: 4),
      );
      final bannedHashtags = await _loadBannedHashtags(
        timeout: const Duration(seconds: 3),
      );

      final policy = TaggingPolicy(
        bannedHashtags: bannedHashtags,
        blockedUsernames: blockedHandles,
        blockedUserIds: blockedIds,
        refreshedAt: now,
      );
      _cachedPolicy = policy;
      _cachedAt = now;
      return policy;
    } catch (_) {
      final fallback = _cachedPolicy ?? const TaggingPolicy.empty();
      if (_cachedPolicy == null) {
        _cachedPolicy = fallback;
        _cachedAt = now;
      }
      return fallback;
    }
  }

  Future<Set<String>> _loadBlockedIds(String uid) async {
    try {
      final query = await _firestore
          .collection('blocks')
          .where('srcUid', isEqualTo: uid)
          .limit(200)
          .get();
      final ids = <String>{};
      for (final doc in query.docs) {
        final data = doc.data();
        final dst = (data['dstUid'] ?? '').toString().trim();
        if (dst.isNotEmpty) {
          ids.add(dst);
        }
      }
      return Set<String>.unmodifiable(ids);
    } catch (_) {
      return const <String>{};
    }
  }

  Future<Set<String>> _resolveUsernames(
    Set<String> ids, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (ids.isEmpty) {
      return const <String>{};
    }
    final handles = <String>{};
    final futures = <Future<void>>[];
    for (final id in ids) {
      futures.add(
        UserService.instance
            .getUserById(id, forceRefresh: false)
            .timeout(timeout, onTimeout: () => null)
            .then((models.User? user) {
              final handle = user?.username.trim().toLowerCase();
              if (handle != null && handle.isNotEmpty) {
                handles.add(handle);
              }
            })
            .catchError((_) {
              // Ignore individual lookup errors.
            }),
      );
    }
    await Future.wait(futures, eagerError: false);
    return Set<String>.unmodifiable(handles);
  }

  Future<Set<String>> _loadBannedHashtags({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    const fallback = <String>{
      'nsfw',
      'nefret',
      'illegal',
      'irkcilik',
      'spam',
      'bakim_gerektiren',
      'adultonly',
    };
    try {
      final doc = await _firestore
          .collection('config')
          .doc('tagging_policy')
          .get()
          .timeout(timeout);
      if (!doc.exists) {
        return Set<String>.unmodifiable(fallback);
      }
      final data = doc.data();
      if (data == null) {
        return Set<String>.unmodifiable(fallback);
      }
      final rawList = data['bannedHashtags'];
      if (rawList is Iterable) {
        final entries = rawList
            .map((item) => (item ?? '').toString().trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet();
        if (entries.isNotEmpty) {
          return Set<String>.unmodifiable(entries);
        }
      }
      return Set<String>.unmodifiable(fallback);
    } catch (_) {
      return Set<String>.unmodifiable(fallback);
    }
  }
}
