import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is Map<String, dynamic> && value.containsKey('__type')) {
    return DateTime.now();
  }
  return null;
}

String? _readMediaReference(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is String) {
    final candidate = value.trim();
    return candidate.isEmpty ? null : candidate;
  }

  if (value is Map) {
    try {
      final map = value.cast<dynamic, dynamic>();

      final Object? storagePath =
          map['path'] ??
          map['storagePath'] ??
          map['storage_path'] ??
          map['gsPath'] ??
          map['gs_path'];
      if (storagePath is String && storagePath.trim().isNotEmpty) {
        return storagePath.trim();
      }

      final Object? direct =
          map['url'] ??
          map['uri'] ??
          map['downloadUrl'] ??
          map['downloadURL'] ??
          map['httpsUrl'];
      if (direct is String && direct.trim().isNotEmpty) {
        return direct.trim();
      }

      if (map.containsKey('source') && map['source'] is Map) {
        return _readMediaReference(map['source']);
      }
    } catch (_) {
      // ignore casting issues and fallback to null
    }
  }

  if (value is Iterable) {
    for (final element in value) {
      final resolved = _readMediaReference(element);
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }
  }

  return value.toString().trim().isNotEmpty ? value.toString().trim() : null;
}

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
    required this.members,
    required this.participantMeta,
    required this.readPointers,
    this.lastMessageText,
    this.lastSenderId,
    this.lastMessageId,
    this.lastMessageAt,
    this.updatedAt,
    this.memberCount,
    this.isGroup = false,
  });

  final String id;
  final List<String> members;
  final Map<String, DirectMessageParticipantMeta> participantMeta;
  final Map<String, String?> readPointers;
  final String? lastMessageText;
  final String? lastSenderId;
  final String? lastMessageId;
  final DateTime? lastMessageAt;
  final DateTime? updatedAt;
  final int? memberCount;
  final bool isGroup;

  factory DirectMessageThread.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final members =
        (data['members'] as List?)
            ?.map((member) => member.toString().trim())
            .where((member) => member.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    final rawMeta = data['participantMeta'];
    final participantMeta = <String, DirectMessageParticipantMeta>{};
    if (rawMeta is Map<String, dynamic>) {
      rawMeta.forEach((key, value) {
        participantMeta[key] = DirectMessageParticipantMeta.fromMap(
          value is Map<String, dynamic> ? value : <String, dynamic>{},
        );
      });
    }

    final rawPointers = data['readPointers'];
    final readPointers = <String, String?>{};
    if (rawPointers is Map) {
      rawPointers.forEach((key, value) {
        if (key is String) {
          if (value == null) {
            readPointers[key] = null;
          } else {
            readPointers[key] = value.toString();
          }
        }
      });
    }

    return DirectMessageThread(
      id: doc.id,
      members: members,
      participantMeta: participantMeta,
      readPointers: readPointers,
      lastMessageText: (data['lastMessageText'] ?? data['lastMessage'] ?? '')
          .toString(),
      lastSenderId: (data['lastSenderId'] ?? '').toString(),
      lastMessageId: (data['lastMessageId'] ?? '').toString().trim().isEmpty
          ? null
          : data['lastMessageId'].toString(),
      lastMessageAt: _readTimestamp(data['lastMessageAt']),
      updatedAt: _readTimestamp(data['updatedAt']),
      memberCount: (data['memberCount'] as num?)?.toInt(),
      isGroup: data['isGroup'] == true,
    );
  }

  DirectMessageParticipantMeta? participantFor(String userId) {
    return participantMeta[userId];
  }

  String? otherParticipantId(String currentUserId) {
    for (final member in members) {
      if (member != currentUserId) {
        return member;
      }
    }
    return null;
  }

  bool hasUnread(String userId) {
    final pointer = readPointers[userId];
    if (lastMessageId == null) {
      return false;
    }
    if (!members.contains(userId)) {
      return false;
    }
    if (pointer == null || pointer.isEmpty) {
      return true;
    }
    return pointer != lastMessageId;
  }
}

class DirectMessageExternalMedia {
  const DirectMessageExternalMedia({
    required this.url,
    required this.type,
    required this.safe,
    this.originDomain,
  });

  final String url;
  final String type;
  final bool safe;
  final String? originDomain;

  factory DirectMessageExternalMedia.fromMap(dynamic data) {
    if (data is! Map) {
      return const DirectMessageExternalMedia(
        url: '',
        type: 'unknown',
        safe: false,
      );
    }

    final map = data.cast<String, dynamic>();
    return DirectMessageExternalMedia(
      url: (map['url'] ?? '').toString(),
      type: (map['type'] ?? 'unknown').toString(),
      safe: map['safe'] == true,
      originDomain: (map['originDomain'] ?? '').toString().trim().isEmpty
          ? null
          : map['originDomain'].toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type,
      'safe': safe,
      if (originDomain != null) 'originDomain': originDomain,
    };
  }
}

class DirectMessageTombstone {
  const DirectMessageTombstone({required this.active, this.at, this.by});

  final bool active;
  final DateTime? at;
  final String? by;

  factory DirectMessageTombstone.fromMap(dynamic data) {
    if (data is! Map) {
      return const DirectMessageTombstone(active: false);
    }
    final map = data.cast<String, dynamic>();
    return DirectMessageTombstone(
      active: map['active'] == true,
      at: _readTimestamp(map['at']),
      by: (map['by'] ?? '').toString().trim().isEmpty
          ? null
          : map['by'].toString(),
    );
  }
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.createdAt,
    required this.updatedAt,
    this.text,
    this.media = const <String>[],
    this.mediaExternal,
    this.deletedFor = const <String, bool>{},
    this.tombstone,
    this.editAllowedUntil,
    this.editedAt,
    this.editedBy,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? text;
  final List<String> media;
  final DirectMessageExternalMedia? mediaExternal;
  final Map<String, bool> deletedFor;
  final DirectMessageTombstone? tombstone;
  final DateTime? editAllowedUntil;
  final DateTime? editedAt;
  final String? editedBy;

  bool get isTombstoned => tombstone?.active == true;

  bool isDeletedFor(String userId) {
    return deletedFor[userId] ?? false;
  }

  bool get hasText => (text ?? '').trim().isNotEmpty;

  bool get hasMedia => media.isNotEmpty || mediaExternal != null;

  bool get canEdit {
    if (isTombstoned) {
      return false;
    }
    return editAllowedUntil?.isAfter(DateTime.now()) ?? false;
  }

  factory DirectMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final conversationId = doc.reference.parent.parent?.id ?? '';

    final mediaRaw = data['media'];
    final media = mediaRaw is List
        ? mediaRaw
              .map(_readMediaReference)
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    final deletedRaw = data['deletedFor'];
    final deletedFor = <String, bool>{};
    if (deletedRaw is Map) {
      deletedRaw.forEach((key, value) {
        if (key is String) {
          deletedFor[key] = value == true;
        }
      });
    }

    final editedRaw = data['edited'];
    DateTime? editedAt;
    String? editedBy;
    if (editedRaw is Map<String, dynamic>) {
      editedAt = _readTimestamp(editedRaw['at']);
      final by = (editedRaw['by'] ?? '').toString().trim();
      if (by.isNotEmpty) {
        editedBy = by;
      }
    }

    return DirectMessage(
      id: doc.id,
      conversationId: conversationId,
      senderId: (data['senderId'] ?? '').toString(),
      text: data['text']?.toString(),
      createdAt: _readTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _readTimestamp(data['updatedAt']) ?? DateTime.now(),
      media: media,
      mediaExternal: data['mediaExternal'] != null
          ? DirectMessageExternalMedia.fromMap(data['mediaExternal'])
          : null,
      deletedFor: deletedFor,
      tombstone: data['tombstone'] != null
          ? DirectMessageTombstone.fromMap(data['tombstone'])
          : const DirectMessageTombstone(active: false),
      editAllowedUntil: _readTimestamp(data['editAllowedUntil']),
      editedAt: editedAt,
      editedBy: editedBy,
    );
  }
}
