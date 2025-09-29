import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/follow_models.dart';
import '../models/user_model.dart';

class FollowService {
  FollowService._();

  static final FollowService instance = FollowService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _followDoc(
    String srcUid,
    String dstUid,
  ) =>
      _firestore.collection('follows').doc('${srcUid}_$dstUid');

  DocumentReference<Map<String, dynamic>> _blockDoc(
    String srcUid,
    String dstUid,
  ) =>
      _firestore.collection('blocks').doc('${srcUid}_$dstUid');

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

    final followSnap = await _followDoc(viewerId, normalizedTarget).get();
    final reverseSnap = await _followDoc(normalizedTarget, viewerId).get();
    final outgoingBlockSnap = await _blockDoc(viewerId, normalizedTarget).get();
    final incomingBlockSnap = await _blockDoc(normalizedTarget, viewerId).get();

    final followEdge = _parseFollowSnapshot(followSnap);
    final reverseEdge = _parseFollowSnapshot(reverseSnap);
    final outgoingBlock = _parseBlockSnapshot(outgoingBlockSnap);
    final incomingBlock = _parseBlockSnapshot(incomingBlockSnap);

    return FollowRelationship(
      state: _resolveState(
        viewerId: viewerId,
        targetUid: normalizedTarget,
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
      if (!(followReady && reverseReady && outgoingBlockReady && incomingBlockReady)) {
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
              targetUid: normalizedTarget,
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
      _followDoc(viewerId, normalizedTarget).snapshots().listen(
        (snapshot) {
          followSnapshot = snapshot;
          followReady = true;
          emitIfReady();
        },
        onError: controller.addError,
      ),
      _followDoc(normalizedTarget, viewerId).snapshots().listen(
        (snapshot) {
          reverseSnapshot = snapshot;
          reverseReady = true;
          emitIfReady();
        },
        onError: controller.addError,
      ),
      _blockDoc(viewerId, normalizedTarget).snapshots().listen(
        (snapshot) {
          outgoingBlockSnapshot = snapshot;
          outgoingBlockReady = true;
          emitIfReady();
        },
        onError: controller.addError,
      ),
      _blockDoc(normalizedTarget, viewerId).snapshots().listen(
        (snapshot) {
          incomingBlockSnapshot = snapshot;
          incomingBlockReady = true;
          emitIfReady();
        },
        onError: controller.addError,
      ),
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

    final desiredStatus =
        target.isPrivate ? FollowEdgeStatus.pending : FollowEdgeStatus.active;

    await _firestore.runTransaction((transaction) async {
      final outgoingBlockRef =
          _blockDoc(normalizedViewer, normalizedTarget);
      final incomingBlockRef =
          _blockDoc(normalizedTarget, normalizedViewer);

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

      final followRef = _followDoc(normalizedViewer, normalizedTarget);
      final snapshot = await transaction.get(followRef);
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
      final currentStatus =
          FollowEdgeStatusMapper.fromFirestore(data['status'] as String?);

      if (currentStatus == desiredStatus) {
        transaction.update(followRef, {
          'updatedAt': now,
        });
        return;
      }

      transaction.update(followRef, {
        'status': desiredStatus.asFirestoreValue,
        'updatedAt': now,
      });
    });

    return getRelationship(normalizedTarget);
  }

  Future<FollowRelationship> cancelRequest(String targetUid) async {
    final viewerId = _requireCurrentUserId();
    final normalizedTarget = targetUid.trim();

    await _updateEdgeStatus(
      srcUid: viewerId,
      dstUid: normalizedTarget,
      nextStatus: FollowEdgeStatus.removed,
    );

    return getRelationship(normalizedTarget);
  }

  Future<FollowRelationship> unfollowUser(String targetUid) async {
    final viewerId = _requireCurrentUserId();
    final normalizedTarget = targetUid.trim();

    await _updateEdgeStatus(
      srcUid: viewerId,
      dstUid: normalizedTarget,
      nextStatus: FollowEdgeStatus.removed,
    );

    return getRelationship(normalizedTarget);
  }

  Future<FollowRelationship> acceptRequest(String followerUid) async {
    final viewerId = _requireCurrentUserId();
    final normalizedFollower = followerUid.trim();

    await _updateEdgeStatus(
      srcUid: normalizedFollower,
      dstUid: viewerId,
      nextStatus: FollowEdgeStatus.active,
    );

    return getRelationship(normalizedFollower);
  }

  Future<FollowRelationship> declineRequest(String followerUid) async {
    final viewerId = _requireCurrentUserId();
    final normalizedFollower = followerUid.trim();

    await _updateEdgeStatus(
      srcUid: normalizedFollower,
      dstUid: viewerId,
      nextStatus: FollowEdgeStatus.removed,
    );

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

  Future<void> _updateEdgeStatus({
    required String srcUid,
    required String dstUid,
    required FollowEdgeStatus nextStatus,
  }) async {
    if (srcUid.isEmpty || dstUid.isEmpty) {
      throw ArgumentError('Geçersiz takip kenarı.');
    }

    await _firestore.runTransaction((transaction) async {
      final followRef = _followDoc(srcUid, dstUid);
      final snapshot = await transaction.get(followRef);
      if (!snapshot.exists) {
        return;
      }

      transaction.update(followRef, {
        'status': nextStatus.asFirestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<bool> isFollowing(String targetUid) async {
    final viewerId = _requireCurrentUserId();
    final normalizedTarget = targetUid.trim();
    if (normalizedTarget.isEmpty) return false;

    final snapshot = await _followDoc(viewerId, normalizedTarget).get();
    if (!snapshot.exists) return false;
    final data = snapshot.data();
    if (data == null) return false;
    final status =
        FollowEdgeStatusMapper.fromFirestore(data['status'] as String?);
    return status.isActive;
  }
}
