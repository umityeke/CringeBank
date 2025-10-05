import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/direct_message.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class DirectMessageService {
  DirectMessageService._();

  static final DirectMessageService instance = DirectMessageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _threadsCollection = 'direct_message_threads';
  static const String _messagesSubcollection = 'messages';

  Stream<List<DirectMessageThread>> watchThreads(String userId) {
    final normalizedId = userId.trim();
    if (normalizedId.isEmpty) {
      return const Stream<List<DirectMessageThread>>.empty();
    }

    return _firestore
        .collection(_threadsCollection)
        .where('participants', arrayContains: normalizedId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(DirectMessageThread.fromDoc)
              .toList(growable: false),
        );
  }

  Stream<List<DirectMessage>> watchMessages(String userId, String otherUserId) {
    final threadId = _threadIdFor(userId, otherUserId);
    if (threadId.isEmpty) {
      return const Stream<List<DirectMessage>>.empty();
    }

    return _firestore
        .collection(_threadsCollection)
        .doc(threadId)
        .collection(_messagesSubcollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(DirectMessage.fromDoc).toList(growable: false),
        );
  }

  Future<void> sendMessage({
    required User sender,
    required User recipient,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    final senderId = sender.id.trim();
    final recipientId = recipient.id.trim();
    if (senderId.isEmpty || recipientId.isEmpty) {
      throw ArgumentError('Sender and recipient must have valid identifiers.');
    }

    final threadId = _threadIdFor(senderId, recipientId);
    if (threadId.isEmpty) {
      throw StateError('Failed to resolve a thread identifier.');
    }

    final threadRef = _firestore.collection(_threadsCollection).doc(threadId);
    final messageRef = threadRef.collection(_messagesSubcollection).doc();

    final participantMeta = {
      senderId: {
        'displayName': sender.displayName,
        'username': sender.username,
        'avatar': sender.avatar,
      },
      recipientId: {
        'displayName': recipient.displayName,
        'username': recipient.username,
        'avatar': recipient.avatar,
      },
    };

    await _firestore.runTransaction((transaction) async {
      final threadSnapshot = await transaction.get(threadRef);

      if (!threadSnapshot.exists) {
        transaction.set(threadRef, {
          'participants': <String>[senderId, recipientId],
          'lastMessage': trimmedText,
          'lastSenderId': senderId,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'participantMeta': participantMeta,
          'unreadCount': 0,
        });
      } else {
        transaction.update(threadRef, {
          'lastMessage': trimmedText,
          'lastSenderId': senderId,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'participantMeta': participantMeta,
        });
      }

      transaction.set(messageRef, {
        'threadId': threadId,
        'senderId': senderId,
        'text': trimmedText,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<User?> ensureUserLoaded(String userId) async {
    final cached = UserService.instance.currentUser;
    if (cached != null && cached.id == userId) {
      return cached;
    }
    return UserService.instance.getUserById(userId, forceRefresh: false);
  }

  String _threadIdFor(String userA, String userB) {
    final normalizedA = userA.trim();
    final normalizedB = userB.trim();

    if (normalizedA.isEmpty || normalizedB.isEmpty) {
      return '';
    }

    final sorted = [normalizedA, normalizedB]..sort();
    return sorted.join('_');
  }
}
