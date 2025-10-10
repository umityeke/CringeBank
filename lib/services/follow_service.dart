import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../models/follow_models.dart';
import '../models/user_model.dart';
import 'messaging_feature_service.dart';
import 'telemetry/callable_latency_tracker.dart';
import 'telemetry/sql_mirror_latency_monitor.dart';

class FollowService {
  FollowService._();

  static final FollowService instance = FollowService._();

  static const Duration _relationshipPollInterval = Duration(seconds: 5);
  static const String _callCategory = 'follow';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  DocumentReference<Map<String, dynamic>> _followDoc(
    String srcUid,
    String dstUid,
  ) => _firestore.collection('follows').doc('${srcUid}_$dstUid');

  DocumentReference<Map<String, dynamic>> _blockDoc(
    String srcUid,
    String dstUid,
  ) => _firestore.collection('blocks').doc('${srcUid}_$dstUid');

  String _requireCurrentUserId() {
    final uid = _auth.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      throw StateError('Bu işlem için önce giriş yapmalısın.');
    }
    return uid;
  }

  Future<FollowRelationship> getRelationship(String targetUid) async {
    final viewerId = _requireCurrentUserId();
    final normalizedTarget = targetUid.trim();
    if (normalizedTarget.isEmpty) {
      throw ArgumentError('Hedef kullanıcı kimliği gerekli.');
    }

    if (viewerId == normalizedTarget) {
      return const FollowRelationship(state: FollowRelationshipState.following);
    }

    if (MessagingFeatureService.instance.isSqlMirrorReadEnabled) {
      return _getRelationshipViaSql(
        viewerId: viewerId,
        targetUid: normalizedTarget,
      );
    }

    return _getRelationshipViaFirestore(
      viewerId: viewerId,
      targetUid: normalizedTarget,
    );
  }

  Stream<FollowRelationship> watchRelationship(String targetUid) {
    final viewerId = _requireCurrentUserId();
    final normalizedTarget = targetUid.trim();
    if (normalizedTarget.isEmpty) {
      throw ArgumentError('Hedef kullanıcı kimliği gerekli.');
    }

    if (viewerId == normalizedTarget) {
      return Stream<FollowRelationship>.value(
        const FollowRelationship(state: FollowRelationshipState.following),
      );
    }

    if (MessagingFeatureService.instance.isSqlMirrorReadEnabled) {
      return _watchRelationshipViaSql(
        viewerId: viewerId,
        targetUid: normalizedTarget,
      );
    }

    return _watchRelationshipViaFirestore(
      viewerId: viewerId,
      targetUid: normalizedTarget,
    );
  }

  Future<FollowRelationship> _getRelationshipViaFirestore({
    required String viewerId,
    required String targetUid,
  }) async {
    final followSnap = await _followDoc(viewerId, targetUid).get();
    final reverseSnap = await _followDoc(targetUid, viewerId).get();
    final outgoingBlockSnap = await _blockDoc(viewerId, targetUid).get();
    final incomingBlockSnap = await _blockDoc(targetUid, viewerId).get();

    final followEdge = _parseFollowSnapshot(followSnap);
    final reverseEdge = _parseFollowSnapshot(reverseSnap);
    final outgoingBlock = _parseBlockSnapshot(outgoingBlockSnap);
    final incomingBlock = _parseBlockSnapshot(incomingBlockSnap);

    return FollowRelationship(
      state: _resolveState(
        viewerId: viewerId,
        targetUid: targetUid,
        outgoing: followEdge,
        incoming: reverseEdge,
        outgoingBlock: outgoingBlock,
        incomingBlock: incomingBlock,
      ),
      follow: followEdge,
      outgoingBlock: outgoingBlock,
      incomingBlock: incomingBlock,
    );
  }

  Stream<FollowRelationship> _watchRelationshipViaFirestore({
    required String viewerId,
    required String targetUid,
  }) {
    final controller = StreamController<FollowRelationship>.broadcast();

    DocumentSnapshot<Map<String, dynamic>>? followSnapshot;
    DocumentSnapshot<Map<String, dynamic>>? reverseSnapshot;
    DocumentSnapshot<Map<String, dynamic>>? outgoingBlockSnapshot;
    DocumentSnapshot<Map<String, dynamic>>? incomingBlockSnapshot;

    bool followReady = false;
    bool reverseReady = false;
    bool outgoingBlockReady = false;
    bool incomingBlockReady = false;

    void emitIfReady() {
      if (!(followReady &&
          reverseReady &&
          outgoingBlockReady &&
          incomingBlockReady)) {
        return;
      }

      final followEdge = _parseFollowSnapshot(followSnapshot);
      final reverseEdge = _parseFollowSnapshot(reverseSnapshot);
      final outgoingBlock = _parseBlockSnapshot(outgoingBlockSnapshot);
      final incomingBlock = _parseBlockSnapshot(incomingBlockSnapshot);

      if (!controller.isClosed) {
        controller.add(
          FollowRelationship(
            state: _resolveState(
              viewerId: viewerId,
              targetUid: targetUid,
              outgoing: followEdge,
              incoming: reverseEdge,
              outgoingBlock: outgoingBlock,
              incomingBlock: incomingBlock,
            ),
            follow: followEdge,
            outgoingBlock: outgoingBlock,
            incomingBlock: incomingBlock,
          ),
        );
      }
    }

    final subscriptions =
        <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[
          _followDoc(viewerId, targetUid).snapshots().listen((snapshot) {
            followSnapshot = snapshot;
            followReady = true;
            emitIfReady();
          }, onError: controller.addError),
          _followDoc(targetUid, viewerId).snapshots().listen((snapshot) {
            reverseSnapshot = snapshot;
            reverseReady = true;
            emitIfReady();
          }, onError: controller.addError),
          _blockDoc(viewerId, targetUid).snapshots().listen((snapshot) {
            outgoingBlockSnapshot = snapshot;
            outgoingBlockReady = true;
            emitIfReady();
          }, onError: controller.addError),
          _blockDoc(targetUid, viewerId).snapshots().listen((snapshot) {
            incomingBlockSnapshot = snapshot;
            incomingBlockReady = true;
            emitIfReady();
          }, onError: controller.addError),
        ];

    controller
      ..onCancel = () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
      }
      ..onListen = emitIfReady;

    return controller.stream;
  }

  Stream<FollowRelationship> _watchRelationshipViaSql({
    required String viewerId,
    required String targetUid,
  }) {
    final controller = StreamController<FollowRelationship>.broadcast();
    final subscriptions =
        <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];

    Timer? pollTimer;
    bool isClosed = false;
    bool isFetching = false;

    FollowEdge? outgoingEdge;
    FollowEdge? incomingEdge;
    BlockEdge? outgoingBlock;
    BlockEdge? incomingBlock;

    bool sqlReady = false;
    bool outgoingBlockReady = false;
    bool incomingBlockReady = false;

    void emitIfReady() {
      if (!sqlReady ||
          !outgoingBlockReady ||
          !incomingBlockReady ||
          controller.isClosed) {
        return;
      }

      final relationshipState = _resolveState(
        viewerId: viewerId,
        targetUid: targetUid,
        outgoing: outgoingEdge,
        incoming: incomingEdge,
        outgoingBlock: outgoingBlock,
        incomingBlock: incomingBlock,
      );

      controller.add(
        FollowRelationship(
          state: relationshipState,
          follow: outgoingEdge,
          outgoingBlock: outgoingBlock,
          incomingBlock: incomingBlock,
        ),
      );
    }

    Future<void> fetchSqlSnapshot() async {
      if (isClosed || isFetching) {
        return;
      }
      isFetching = true;
      try {
        final snapshot = await _fetchSqlFollowSnapshot(
          viewerId: viewerId,
          targetUid: targetUid,
        );
        outgoingEdge = snapshot.outgoing;
        incomingEdge = snapshot.incoming;

        if (snapshot.outgoingBlock != null) {
          outgoingBlock = snapshot.outgoingBlock;
          outgoingBlockReady = true;
        }

        if (snapshot.incomingBlock != null) {
          incomingBlock = snapshot.incomingBlock;
          incomingBlockReady = true;
        }

        sqlReady = true;
        emitIfReady();
      } catch (error, stackTrace) {
        if (!isClosed && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        isFetching = false;
      }
    }

    Future<void> primeBlocks() async {
      try {
        final pair = await _fetchBlockEdges(
          viewerId: viewerId,
          targetUid: targetUid,
        );
        if (isClosed || controller.isClosed) {
          return;
        }
        outgoingBlock = pair.outgoing;
        incomingBlock = pair.incoming;
        outgoingBlockReady = true;
        incomingBlockReady = true;
        emitIfReady();
      } catch (error, stackTrace) {
        if (!isClosed && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    subscriptions.add(
      _blockDoc(viewerId, targetUid).snapshots().listen((snapshot) {
        outgoingBlock = _parseBlockSnapshot(snapshot);
        outgoingBlockReady = true;
        emitIfReady();
      }, onError: controller.addError),
    );

    subscriptions.add(
      _blockDoc(targetUid, viewerId).snapshots().listen((snapshot) {
        incomingBlock = _parseBlockSnapshot(snapshot);
        incomingBlockReady = true;
        emitIfReady();
      }, onError: controller.addError),
    );

    controller
      ..onListen = () {
        primeBlocks();
        fetchSqlSnapshot();
        pollTimer = Timer.periodic(
          _relationshipPollInterval,
          (_) => fetchSqlSnapshot(),
        );
      }
      ..onCancel = () async {
        if (isClosed) {
          return;
        }
        isClosed = true;
        pollTimer?.cancel();
        for (final sub in subscriptions) {
          await sub.cancel();
        }
      }
      ..onPause = () {
        pollTimer?.cancel();
      }
      ..onResume = () {
        if (isClosed) {
          return;
        }
        pollTimer?.cancel();
        pollTimer = Timer.periodic(
          _relationshipPollInterval,
          (_) => fetchSqlSnapshot(),
        );
      };

    return controller.stream;
  }

  Future<FollowRelationship> _getRelationshipViaSql({
    required String viewerId,
    required String targetUid,
  }) async {
    final snapshot = await _fetchSqlFollowSnapshot(
      viewerId: viewerId,
      targetUid: targetUid,
    );

    BlockEdge? outgoingBlock = snapshot.outgoingBlock;
    BlockEdge? incomingBlock = snapshot.incomingBlock;

    if (outgoingBlock == null || incomingBlock == null) {
      final fallback = await _fetchBlockEdges(
        viewerId: viewerId,
        targetUid: targetUid,
      );
      outgoingBlock ??= fallback.outgoing;
      incomingBlock ??= fallback.incoming;
    }

    final state = _resolveState(
      viewerId: viewerId,
      targetUid: targetUid,
      outgoing: snapshot.outgoing,
      incoming: snapshot.incoming,
      outgoingBlock: outgoingBlock,
      incomingBlock: incomingBlock,
    );

    return FollowRelationship(
      state: state,
      follow: snapshot.outgoing,
      outgoingBlock: outgoingBlock,
      incomingBlock: incomingBlock,
    );
  }

  Future<_SqlFollowSnapshot> _fetchSqlFollowSnapshot({
    required String viewerId,
    required String targetUid,
  }) async {
    final payload = {'viewerUid': viewerId, 'targetUid': targetUid};

    final response = await _functions.callWithLatency<dynamic>(
      'sqlGatewayFollowGetRelationship',
      payload: payload,
      category: _callCategory,
      onMeasured: (elapsedMs) {
        SqlMirrorLatencyMonitor.instance.record(
          operation: 'followGetRelationship',
          elapsedMs: elapsedMs,
        );
      },
    );

    final responseMap =
        _coerceStringKeyedMap(response.data) ?? <String, dynamic>{};
    final relationshipMap =
        _coerceStringKeyedMap(responseMap['relationship']) ??
        <String, dynamic>{};

    return _SqlFollowSnapshot(
      outgoing: _parseSqlFollowEdge(relationshipMap['outgoing']),
      incoming: _parseSqlFollowEdge(relationshipMap['incoming']),
      outgoingBlock: _parseSqlBlockEdge(relationshipMap['outgoingBlock']),
      incomingBlock: _parseSqlBlockEdge(relationshipMap['incomingBlock']),
    );
  }

  Future<_BlockEdgePair> _fetchBlockEdges({
    required String viewerId,
    required String targetUid,
  }) async {
    try {
      final results = await Future.wait([
        _blockDoc(viewerId, targetUid).get(),
        _blockDoc(targetUid, viewerId).get(),
      ]);

      return _BlockEdgePair(
        outgoing: _parseBlockSnapshot(results[0]),
        incoming: _parseBlockSnapshot(results[1]),
      );
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Failed to fetch block edges for follow relationship',
      );
      return const _BlockEdgePair();
    }
  }

  FollowEdge? _parseSqlFollowEdge(dynamic raw) {
    final map = _coerceStringKeyedMap(raw);
    if (map == null || map.isEmpty) {
      return null;
    }
    return FollowEdge.fromSql(map);
  }

  BlockEdge? _parseSqlBlockEdge(dynamic raw) {
    final map = _coerceStringKeyedMap(raw);
    if (map == null || map.isEmpty) {
      return null;
    }
    return BlockEdge.fromSql(map);
  }

  Map<String, dynamic>? _coerceStringKeyedMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      final result = <String, dynamic>{};
      raw.forEach((key, value) {
        if (key == null) {
          return;
        }
        result[key.toString()] = value;
      });
      return result;
    }
    return null;
  }

  FollowEdge? _parseFollowSnapshot(
    DocumentSnapshot<Map<String, dynamic>>? snapshot,
  ) {
    if (snapshot == null || !snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null) return null;
    return FollowEdge.fromMap(data, id: snapshot.id);
  }

  BlockEdge? _parseBlockSnapshot(
    DocumentSnapshot<Map<String, dynamic>>? snapshot,
  ) {
    if (snapshot == null || !snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null) return null;
    return BlockEdge.fromMap(data, id: snapshot.id);
  }

  FollowRelationshipState _resolveState({
    required String viewerId,
    required String targetUid,
    FollowEdge? outgoing,
    FollowEdge? incoming,
    BlockEdge? outgoingBlock,
    BlockEdge? incomingBlock,
  }) {
    final outgoingBlocked = outgoingBlock != null;
    final incomingBlocked = incomingBlock != null;

    if (outgoingBlocked && incomingBlocked) {
      return FollowRelationshipState.blockedMutual;
    }
    if (outgoingBlocked) {
      return FollowRelationshipState.blockedByMe;
    }
    if (incomingBlocked) {
      return FollowRelationshipState.blockedByThem;
    }

    if (outgoing != null && outgoing.status.isActive) {
      return FollowRelationshipState.following;
    }

    if (outgoing != null && outgoing.status.isPending) {
      return FollowRelationshipState.outgoingRequest;
    }

    if (incoming != null && incoming.status.isPending) {
      return FollowRelationshipState.incomingRequest;
    }

    return FollowRelationshipState.none;
  }

  Future<FollowRelationship> followUser({
    required User viewer,
    required User target,
  }) async {
    final viewerId = _requireCurrentUserId();
    final normalizedViewer = viewer.id.trim();
    final normalizedTarget = target.id.trim();

    if (viewerId != normalizedViewer) {
      throw StateError('Yetkisiz işlem.');
    }

    if (normalizedViewer.isEmpty || normalizedTarget.isEmpty) {
      throw ArgumentError('Takip kenarı için kullanıcı kimlikleri gerekli.');
    }

    if (normalizedViewer == normalizedTarget) {
      throw StateError('Kendini takip edemezsin.');
    }

    final desiredStatus = target.isPrivate
        ? FollowEdgeStatus.pending
        : FollowEdgeStatus.active;

    final followRef = _followDoc(normalizedViewer, normalizedTarget);
    DocumentSnapshot<Map<String, dynamic>>? previousSnapshot;

    await _firestore.runTransaction((transaction) async {
      final outgoingBlockRef = _blockDoc(normalizedViewer, normalizedTarget);
      final incomingBlockRef = _blockDoc(normalizedTarget, normalizedViewer);

      final incomingBlockSnap = await transaction.get(incomingBlockRef);
      if (incomingBlockSnap.exists) {
        throw StateError('Bu kullanıcı seni engellemiş.');
      }

      final existingBlockSnap = await transaction.get(outgoingBlockRef);
      if (existingBlockSnap.exists) {
        throw StateError(
          'Bu kullanıcıyı takip etmek için önce engeli kaldırmalısın.',
        );
      }

      final snapshot = await transaction.get(followRef);
      previousSnapshot = snapshot;
      final now = FieldValue.serverTimestamp();

      if (!snapshot.exists) {
        transaction.set(followRef, {
          'srcUid': normalizedViewer,
          'dstUid': normalizedTarget,
          'status': desiredStatus.asFirestoreValue,
          'createdAt': now,
          'updatedAt': now,
        });
        return;
      }

      final data = snapshot.data()!;
      final currentStatus = FollowEdgeStatusMapper.fromFirestore(
        data['status'] as String?,
      );

      if (currentStatus == desiredStatus) {
        transaction.update(followRef, {'updatedAt': now});
        return;
      }

      transaction.update(followRef, {
        'status': desiredStatus.asFirestoreValue,
        'updatedAt': now,
      });
    });

    final currentSnapshot = await followRef.get();
    final mirrorBundle = _FollowMirrorBundle(
      userId: normalizedViewer,
      targetId: normalizedTarget,
      operation: previousSnapshot?.exists ?? false ? 'update' : 'create',
      document: currentSnapshot.data(),
      previousDocument: previousSnapshot?.data(),
    );

    await _mirrorFollowEdgeToSql(mirrorBundle);

    return getRelationship(normalizedTarget);
  }

  Future<FollowRelationship> cancelRequest(String targetUid) async {
    final viewerId = _requireCurrentUserId();
    final normalizedTarget = targetUid.trim();

    final mirrorBundle = await _updateEdgeStatus(
      srcUid: viewerId,
      dstUid: normalizedTarget,
      nextStatus: FollowEdgeStatus.removed,
    );

    await _mirrorFollowEdgeToSql(mirrorBundle);

    return getRelationship(normalizedTarget);
  }

  Future<FollowRelationship> unfollowUser(String targetUid) async {
    final viewerId = _requireCurrentUserId();
    final normalizedTarget = targetUid.trim();

    final mirrorBundle = await _updateEdgeStatus(
      srcUid: viewerId,
      dstUid: normalizedTarget,
      nextStatus: FollowEdgeStatus.removed,
    );

    await _mirrorFollowEdgeToSql(mirrorBundle);

    return getRelationship(normalizedTarget);
  }

  Future<FollowRelationship> acceptRequest(String followerUid) async {
    final viewerId = _requireCurrentUserId();
    final normalizedFollower = followerUid.trim();

    final mirrorBundle = await _updateEdgeStatus(
      srcUid: normalizedFollower,
      dstUid: viewerId,
      nextStatus: FollowEdgeStatus.active,
    );

    await _mirrorFollowEdgeToSql(mirrorBundle);

    return getRelationship(normalizedFollower);
  }

  Future<FollowRelationship> declineRequest(String followerUid) async {
    final viewerId = _requireCurrentUserId();
    final normalizedFollower = followerUid.trim();

    final mirrorBundle = await _updateEdgeStatus(
      srcUid: normalizedFollower,
      dstUid: viewerId,
      nextStatus: FollowEdgeStatus.removed,
    );

    await _mirrorFollowEdgeToSql(mirrorBundle);

    return getRelationship(normalizedFollower);
  }

  Future<void> blockUser(String targetUid) async {
    final viewerId = _requireCurrentUserId();
    final normalizedTarget = targetUid.trim();

    await _firestore.runTransaction((transaction) async {
      final blockRef = _blockDoc(viewerId, normalizedTarget);
      final outgoingFollowRef = _followDoc(viewerId, normalizedTarget);
      final incomingFollowRef = _followDoc(normalizedTarget, viewerId);

      final now = FieldValue.serverTimestamp();

      transaction.set(blockRef, {
        'srcUid': viewerId,
        'dstUid': normalizedTarget,
        'createdAt': now,
      });

      final outgoingSnap = await transaction.get(outgoingFollowRef);
      if (outgoingSnap.exists) {
        transaction.update(outgoingFollowRef, {
          'status': FollowEdgeStatus.removed.asFirestoreValue,
          'updatedAt': now,
        });
      }

      final incomingSnap = await transaction.get(incomingFollowRef);
      if (incomingSnap.exists) {
        transaction.update(incomingFollowRef, {
          'status': FollowEdgeStatus.removed.asFirestoreValue,
          'updatedAt': now,
        });
      }
    });
  }

  Future<void> unblockUser(String targetUid) async {
    final viewerId = _requireCurrentUserId();
    final normalizedTarget = targetUid.trim();

    await _blockDoc(viewerId, normalizedTarget).delete();
  }

  Future<_FollowMirrorBundle?> _updateEdgeStatus({
    required String srcUid,
    required String dstUid,
    required FollowEdgeStatus nextStatus,
  }) async {
    if (srcUid.isEmpty || dstUid.isEmpty) {
      throw ArgumentError('Geçersiz takip kenarı.');
    }

    final followRef = _followDoc(srcUid, dstUid);
    DocumentSnapshot<Map<String, dynamic>>? previousSnapshot;
    var updated = false;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(followRef);
      previousSnapshot = snapshot;
      if (!snapshot.exists) {
        return;
      }

      transaction.update(followRef, {
        'status': nextStatus.asFirestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      updated = true;
    });

    if (!updated) {
      return null;
    }

    final currentSnapshot = await followRef.get();

    return _FollowMirrorBundle(
      userId: srcUid,
      targetId: dstUid,
      operation: 'update',
      document: currentSnapshot.data(),
      previousDocument: previousSnapshot?.data(),
    );
  }

  Future<void> _mirrorFollowEdgeToSql(_FollowMirrorBundle? bundle) async {
    if (bundle == null) {
      return;
    }

    final features = MessagingFeatureService.instance;
    if (!features.isSqlMirrorDoubleWriteEnabled) {
      return;
    }

    final envelope = _buildFollowSqlMirrorEnvelope(bundle);
    if (envelope == null || envelope.isEmpty) {
      return;
    }

    final operationType =
        envelope['type']?.toString() ?? 'follow.edge.${bundle.operation}';

    try {
      await _functions.callWithLatency<dynamic>(
        'sqlGatewayFollowEdgeUpsert',
        payload: envelope,
        category: 'sqlMirror',
        onMeasured: (elapsedMs) {
          SqlMirrorLatencyMonitor.instance.record(
            operation: operationType,
            elapsedMs: elapsedMs,
          );
        },
      );
    } catch (error, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'FollowSqlMirrorFailure',
        fatal: false,
      );
      debugPrint('sqlGatewayFollowEdgeUpsert failed: $error');
    }
  }

  Map<String, dynamic>? _buildFollowSqlMirrorEnvelope(
    _FollowMirrorBundle bundle,
  ) {
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();
    final document = _normalizeFollowDocument(bundle.document, nowIso);
    final previousDocument = _normalizeFollowDocument(
      bundle.previousDocument,
      nowIso,
    );

    if (document == null && previousDocument == null) {
      return null;
    }

    final eventId =
        'follow.edge.${bundle.operation}:${bundle.userId}:${bundle.targetId}:${now.microsecondsSinceEpoch}';

    return {
      'id': eventId,
      'type': 'follow.edge.${bundle.operation}',
      'source': 'flutter://follow-service',
      'time': nowIso,
      'data': {
        'operation': bundle.operation,
        'userId': bundle.userId,
        'targetId': bundle.targetId,
        'timestamp': nowIso,
        'document': document,
        'previousDocument': previousDocument,
        'source': 'flutter://follow-service',
      },
    };
  }

  Map<String, dynamic>? _normalizeFollowDocument(
    Map<String, dynamic>? raw,
    String fallbackIso,
  ) {
    if (raw == null) {
      return null;
    }

    final status = (raw['status'] ?? raw['state'])?.toString().toUpperCase();
    final source = (raw['source'] ?? raw['origin'] ?? 'firestore://follows')
        .toString();
    final createdAt = _coerceIsoString(raw['createdAt']) ?? fallbackIso;
    final updatedAt = _coerceIsoString(raw['updatedAt']) ?? fallbackIso;

    return {
      'status': status ?? 'REMOVED',
      'source': source.isEmpty ? 'firestore://follows' : source,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  String? _coerceIsoString(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      return parsed?.toUtc().toIso8601String();
    }
    return null;
  }

  Future<bool> isFollowing(String targetUid) async {
    final viewerId = _requireCurrentUserId();
    final normalizedTarget = targetUid.trim();
    if (normalizedTarget.isEmpty) return false;

    if (viewerId == normalizedTarget) {
      return true;
    }

    if (MessagingFeatureService.instance.isSqlMirrorReadEnabled) {
      final snapshot = await _fetchSqlFollowSnapshot(
        viewerId: viewerId,
        targetUid: normalizedTarget,
      );
      final followEdge = snapshot.outgoing;
      return followEdge?.status.isActive ?? false;
    }

    final snapshot = await _followDoc(viewerId, normalizedTarget).get();
    if (!snapshot.exists) return false;
    final data = snapshot.data();
    if (data == null) return false;
    final status = FollowEdgeStatusMapper.fromFirestore(
      data['status'] as String?,
    );
    return status.isActive;
  }
}

class _SqlFollowSnapshot {
  const _SqlFollowSnapshot({
    this.outgoing,
    this.incoming,
    this.outgoingBlock,
    this.incomingBlock,
  });

  final FollowEdge? outgoing;
  final FollowEdge? incoming;
  final BlockEdge? outgoingBlock;
  final BlockEdge? incomingBlock;
}

class _BlockEdgePair {
  const _BlockEdgePair({this.outgoing, this.incoming});

  final BlockEdge? outgoing;
  final BlockEdge? incoming;
}

class _FollowMirrorBundle {
  const _FollowMirrorBundle({
    required this.userId,
    required this.targetId,
    required this.operation,
    required this.document,
    required this.previousDocument,
  });

  final String userId;
  final String targetId;
  final String operation;
  final Map<String, dynamic>? document;
  final Map<String, dynamic>? previousDocument;
}
