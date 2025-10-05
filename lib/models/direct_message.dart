import 'package:cloud_firestore/cloud_firestore.dart';

class DirectMessageParticipantMeta {
  const DirectMessageParticipantMeta({
    required this.displayName,
    required this.username,
    required this.avatar,
  });

  final String displayName;
  final String username;
  final String avatar;

  factory DirectMessageParticipantMeta.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const DirectMessageParticipantMeta(
        displayName: 'Bilinmeyen',
        username: 'anonymous',
        avatar: '👤',
      );
    }

    return DirectMessageParticipantMeta(
      displayName: (data['displayName'] ?? data['display_name'] ?? 'Bilinmeyen')
          .toString()
          .trim(),
      username: (data['username'] ?? data['userName'] ?? 'anonymous')
          .toString()
          .trim(),
      avatar: (data['avatar'] ?? data['photo'] ?? '👤').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'displayName': displayName, 'username': username, 'avatar': avatar};
  }
}

class DirectMessageThread {
  const DirectMessageThread({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastMessageAt,
    required this.participantMeta,
    this.unreadCount = 0,
  });

  final String id;
  final List<String> participants;
  final String lastMessage;
  final String lastSenderId;
  final DateTime? lastMessageAt;
  final Map<String, DirectMessageParticipantMeta> participantMeta;
  final int unreadCount;

  factory DirectMessageThread.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final participantsRaw =
        (data['participants'] as List?)
            ?.map((participant) => participant.toString())
            .where((participant) => participant.trim().isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    final participantMetaRaw = data['participantMeta'] as Map<String, dynamic>?;
    final meta = <String, DirectMessageParticipantMeta>{};
    participantMetaRaw?.forEach((key, value) {
      meta[key] = DirectMessageParticipantMeta.fromMap(
        value is Map<String, dynamic> ? value : <String, dynamic>{},
      );
    });

    DateTime? lastMessageAt;
    final timestamp = data['lastMessageAt'];
    if (timestamp is Timestamp) {
      lastMessageAt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      lastMessageAt = timestamp;
    }

    return DirectMessageThread(
      id: doc.id,
      participants: participantsRaw,
      lastMessage: (data['lastMessage'] ?? '').toString(),
      lastSenderId: (data['lastSenderId'] ?? '').toString(),
      lastMessageAt: lastMessageAt,
      participantMeta: meta,
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  DirectMessageParticipantMeta? participantFor(String userId) {
    return participantMeta[userId];
  }

  String? otherParticipantId(String currentUserId) {
    for (final participant in participants) {
      if (participant != currentUserId) {
        return participant;
      }
    }
    return null;
  }
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String text;
  final DateTime createdAt;

  factory DirectMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    DateTime createdAt = DateTime.now();
    final timestamp = data['createdAt'];
    if (timestamp is Timestamp) {
      createdAt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      createdAt = timestamp;
    }

    return DirectMessage(
      id: doc.id,
      threadId: (data['threadId'] ?? '').toString(),
      senderId: (data['senderId'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      createdAt: createdAt,
    );
  }
}
