import 'package:cloud_firestore/cloud_firestore.dart';

class CringeComment {
  final String id;
  final String entryId;
  final String userId;
  final String authorName;
  final String authorHandle;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;
  final String? parentCommentId;
  final int likeCount;
  final List<String> likedByUserIds;

  const CringeComment({
    required this.id,
    required this.entryId,
    required this.userId,
    required this.authorName,
    required this.authorHandle,
    required this.content,
    required this.createdAt,
    this.authorAvatarUrl,
    this.parentCommentId,
    this.likeCount = 0,
    this.likedByUserIds = const [],
  });

  factory CringeComment.fromFirestore(
    Map<String, dynamic> data, {
    required String documentId,
    required String entryId,
  }) {
    DateTime parseCreatedAt(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    final rawParentId = (data['parentCommentId'] as String?)?.trim();
    final parentId = rawParentId == null || rawParentId.isEmpty ? null : rawParentId;
    final likedBy = (data['likedByUserIds'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false);

    return CringeComment(
      id: documentId,
      entryId: entryId,
      userId: (data['userId'] ?? '').toString(),
      authorName: (data['authorName'] ?? data['username'] ?? 'Anonim').toString(),
      authorHandle: (data['authorHandle'] ?? data['userHandle'] ?? '@anonim').toString(),
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
      content: (data['content'] ?? '').toString(),
      createdAt: parseCreatedAt(data['createdAt']),
      parentCommentId: parentId,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? likedBy.length,
      likedByUserIds: likedBy,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'authorName': authorName,
      'authorHandle': authorHandle,
      'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
      'likeCount': likeCount,
      'likedByUserIds': likedByUserIds,
    };
  }

  bool get isReply => parentCommentId != null && parentCommentId!.isNotEmpty;
}
