import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/direct_message.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class DirectMessageAttachmentRequest {
  DirectMessageAttachmentRequest({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

class ConversationEnsureResult {
  const ConversationEnsureResult({
    required this.conversationId,
    required this.created,
  });

  final String conversationId;
  final bool created;
}

class DirectMessageSendResult {
  const DirectMessageSendResult({
    required this.conversationId,
    required this.messageId,
  });

  final String conversationId;
  final String messageId;
}

class DirectMessageBlockStatus {
  const DirectMessageBlockStatus({
    required this.blockedByMe,
    required this.blockedByOther,
  });

  final bool blockedByMe;
  final bool blockedByOther;

  bool get isBlocked => blockedByMe || blockedByOther;
}

class DirectMessageService {
  DirectMessageService._();

  static final DirectMessageService instance = DirectMessageService._();

  static const String _conversationCollection = 'conversations';
  static const String _messagesSubcollection = 'messages';
  static const int _maxAttachmentBytes = 10 * 1024 * 1024; // 10 MB

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<DirectMessageThread>> watchThreads(String userId) {
    final normalizedId = userId.trim();
    if (normalizedId.isEmpty) {
      return const Stream<List<DirectMessageThread>>.empty();
    }

    return _firestore
        .collection(_conversationCollection)
        .where('members', arrayContains: normalizedId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(DirectMessageThread.fromDoc)
              .toList(growable: false);
        });
  }

  Stream<List<DirectMessage>> watchMessages(
    String currentUserId,
    String otherUserId,
  ) {
    final conversationId = _conversationIdFor(currentUserId, otherUserId);
    if (conversationId.isEmpty) {
      return const Stream<List<DirectMessage>>.empty();
    }

    return _firestore
        .collection(_conversationCollection)
        .doc(conversationId)
        .collection(_messagesSubcollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(DirectMessage.fromDoc)
              .toList(growable: false);
        });
  }

  Future<ConversationEnsureResult> ensureConversation({
    required User currentUser,
    required User otherUser,
  }) async {
    final conversationId = _conversationIdFor(currentUser.id, otherUser.id);
    if (conversationId.isEmpty) {
      throw StateError('Conversation kimliği üretilemedi.');
    }

    final callable = _functions.httpsCallable('createConversation');
    final participantMeta = _buildParticipantMeta(currentUser, otherUser);

    final result = await callable.call(<String, dynamic>{
      'otherUserId': otherUser.id,
      'participantMeta': participantMeta,
    });

    final data = result.data as Map<dynamic, dynamic>? ?? {};
    final created = data['created'] == true;

    return ConversationEnsureResult(
      conversationId: conversationId,
      created: created,
    );
  }

  Future<DirectMessageSendResult> sendMessage({
    required User sender,
    required User recipient,
    String? text,
    List<DirectMessageAttachmentRequest> attachments = const [],
    DirectMessageExternalMedia? externalMedia,
  }) async {
    final trimmedText = text?.trim() ?? '';
    final senderId = sender.id.trim();
    final recipientId = recipient.id.trim();

    if (senderId.isEmpty || recipientId.isEmpty) {
      throw ArgumentError('Gönderen ve hedef kullanıcı kimlikleri gerekli.');
    }

    if (trimmedText.isEmpty && attachments.isEmpty && externalMedia == null) {
      throw ArgumentError('Boş mesaj gönderilemez.');
    }

    final conversationId = _conversationIdFor(senderId, recipientId);
    if (conversationId.isEmpty) {
      throw StateError('Conversation kimliği üretilemedi.');
    }

    await ensureConversation(currentUser: sender, otherUser: recipient);

    final messageId = _firestore
        .collection(_conversationCollection)
        .doc(conversationId)
        .collection(_messagesSubcollection)
        .doc()
        .id;

    final mediaPaths = _prepareMediaPaths(
      conversationId: conversationId,
      messageId: messageId,
      attachments: attachments,
    );

    final callable = _functions.httpsCallable('sendMessage');
    final payload = <String, dynamic>{
      'conversationId': conversationId,
      'clientMessageId': messageId,
      'participantMeta': _buildParticipantMeta(sender, recipient),
    };

    if (trimmedText.isNotEmpty) {
      payload['text'] = trimmedText;
    }

    if (mediaPaths.isNotEmpty) {
      payload['media'] = mediaPaths;
    }

    if (externalMedia != null) {
      payload['mediaExternal'] = externalMedia.toMap();
    }

    final response = await callable.call(payload);

    final responseMap = response.data as Map<dynamic, dynamic>? ?? {};
    final responseMessageId = (responseMap['messageId'] ?? messageId)
        .toString()
        .trim();

    await _uploadAttachments(
      storagePaths: mediaPaths,
      attachments: attachments,
    );

    return DirectMessageSendResult(
      conversationId: conversationId,
      messageId: responseMessageId,
    );
  }

  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    String? text,
    DirectMessageExternalMedia? externalMedia,
  }) async {
    if (conversationId.trim().isEmpty || messageId.trim().isEmpty) {
      throw ArgumentError('Geçerli conversation ve mesaj kimlikleri gerekli.');
    }

    final callable = _functions.httpsCallable('editMessage');

    await callable.call(<String, dynamic>{
      'conversationId': conversationId,
      'messageId': messageId,
      if (text != null) 'text': text,
      if (externalMedia != null) 'mediaExternal': externalMedia.toMap(),
    });
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
    bool forEveryone = false,
  }) async {
    if (conversationId.trim().isEmpty || messageId.trim().isEmpty) {
      throw ArgumentError('Geçerli conversation ve mesaj kimlikleri gerekli.');
    }

    final callable = _functions.httpsCallable('deleteMessage');

    await callable.call(<String, dynamic>{
      'conversationId': conversationId,
      'messageId': messageId,
      'deleteMode': forEveryone ? 'for-both' : 'only-me',
    });
  }

  Future<void> markRead({
    required String conversationId,
    required String messageId,
  }) async {
    if (conversationId.trim().isEmpty || messageId.trim().isEmpty) {
      return;
    }

    final callable = _functions.httpsCallable('setReadPointer');
    await callable.call(<String, dynamic>{
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  Future<DirectMessageBlockStatus> getBlockStatus({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final myBlockRef = _firestore
        .collection('blocks')
        .doc(currentUserId)
        .collection('targets')
        .doc(otherUserId);

    final theirBlockRef = _firestore
        .collection('blocks')
        .doc(otherUserId)
        .collection('targets')
        .doc(currentUserId);

    final snapshots = await Future.wait([
      myBlockRef.get(),
      theirBlockRef.get(),
    ]);
    return DirectMessageBlockStatus(
      blockedByMe: snapshots[0].exists,
      blockedByOther: snapshots[1].exists,
    );
  }

  Future<void> blockUser({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final targetRef = _firestore
        .collection('blocks')
        .doc(currentUserId)
        .collection('targets')
        .doc(otherUserId);

    await targetRef.set({'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> unblockUser({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final targetRef = _firestore
        .collection('blocks')
        .doc(currentUserId)
        .collection('targets')
        .doc(otherUserId);

    await targetRef.delete();
  }

  Future<User?> ensureUserLoaded(String userId) async {
    final cached = UserService.instance.currentUser;
    if (cached != null && cached.id == userId) {
      return cached;
    }
    return UserService.instance.getUserById(userId, forceRefresh: false);
  }

  Map<String, Map<String, dynamic>> _buildParticipantMeta(
    User currentUser,
    User otherUser,
  ) {
    return {
      currentUser.id: {
        'displayName': currentUser.displayName,
        'username': currentUser.username,
        'avatar': currentUser.avatar,
      },
      otherUser.id: {
        'displayName': otherUser.displayName,
        'username': otherUser.username,
        'avatar': otherUser.avatar,
      },
    };
  }

  List<String> _prepareMediaPaths({
    required String conversationId,
    required String messageId,
    required List<DirectMessageAttachmentRequest> attachments,
  }) {
    if (attachments.isEmpty) {
      return const <String>[];
    }

    final random = Random.secure();
    final paths = <String>[];
    for (var i = 0; i < attachments.length; i++) {
      final attachment = attachments[i];

      if (attachment.bytes.lengthInBytes > _maxAttachmentBytes) {
        throw ArgumentError('Ek boyutu 10 MB limitini aşıyor.');
      }

      if (!_isAllowedContentType(attachment.contentType)) {
        throw ArgumentError(
          'Desteklenmeyen içerik türü: ${attachment.contentType}',
        );
      }

      final sanitizedName = _sanitizeFileName(attachment.fileName, random);
      paths.add('dm/$conversationId/$messageId/$sanitizedName');
    }
    return paths;
  }

  Future<void> _uploadAttachments({
    required List<String> storagePaths,
    required List<DirectMessageAttachmentRequest> attachments,
  }) async {
    if (storagePaths.isEmpty || attachments.isEmpty) {
      return;
    }

    final uploads = <Future<void>>[];
    for (var i = 0; i < storagePaths.length; i++) {
      final path = storagePaths[i];
      final attachment = attachments[i];
      final ref = _storage.ref(path);

      uploads.add(
        ref.putData(
          attachment.bytes,
          SettableMetadata(contentType: attachment.contentType),
        ),
      );
    }

    await Future.wait(uploads);
  }

  bool _isAllowedContentType(String contentType) {
    final lower = contentType.toLowerCase();
    return lower.startsWith('image/') ||
        lower.startsWith('video/') ||
        lower.startsWith('audio/');
  }

  String _sanitizeFileName(String fileName, Random random) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return 'upload_${random.nextInt(1 << 32)}';
    }

    final normalized = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (normalized.isEmpty) {
      return 'upload_${random.nextInt(1 << 32)}';
    }
    if (normalized.length > 120) {
      return normalized.substring(normalized.length - 120);
    }
    return normalized;
  }

  String _conversationIdFor(String userA, String userB) {
    final normalizedA = userA.trim();
    final normalizedB = userB.trim();

    if (normalizedA.isEmpty || normalizedB.isEmpty) {
      return '';
    }

    final sorted = [normalizedA, normalizedB]..sort();
    return sorted.join('_');
  }
}
