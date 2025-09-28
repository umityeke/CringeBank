import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import '../models/cringe_comment.dart';
import '../models/cringe_entry.dart';
import '../services/cringe_entry_service.dart';
import '../theme/app_theme.dart';
import 'modern_components.dart';

class EntryCommentsSheet extends StatefulWidget {
  final CringeEntry entry;
  final VoidCallback? onCommentAdded;

  const EntryCommentsSheet({
    super.key,
    required this.entry,
    this.onCommentAdded,
  });

  @override
  State<EntryCommentsSheet> createState() => _EntryCommentsSheetState();
}

class _EntryCommentsSheetState extends State<EntryCommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  bool _isSubmitting = false;
  CringeComment? _replyTarget;
  final Set<String> _likingCommentIds = <String>{};
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGrabHandle(),
              _buildHeader(context),
              const SizedBox(height: AppTheme.spacingM),
              Flexible(child: _buildCommentsList()),
              const Divider(height: 1, color: Colors.white10),
              _buildComposer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrabHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacingS),
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingL,
        vertical: AppTheme.spacingM,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.entry.baslik,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Yorumlar',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<List<CringeComment>>(
      stream: CringeEntryService.instance.commentsStream(widget.entry.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.cringeOrange),
          );
        }

        final comments = snapshot.data ?? const <CringeComment>[];
        final flattenedComments = _buildCommentItems(comments);

        if (flattenedComments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              child: Text(
                'İlk yorumu sen yaz! 🙌',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingL,
            vertical: AppTheme.spacingS,
          ),
          itemBuilder: (context, index) => _buildCommentTile(flattenedComments[index]),
          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingM),
          itemCount: flattenedComments.length,
        );
      },
    );
  }

  Widget _buildCommentTile(_CommentListItem item) {
    final comment = item.comment;
    final indent = item.depth == 0 ? 0.0 : AppTheme.spacingM + item.depth * 18.0;

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernAvatar(
            imageUrl: comment.authorAvatarUrl,
            initials: _buildInitials(comment.authorName, comment.authorHandle),
            size: 36,
            isOnline: false,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingXS),
                  Text(
                    _formatTimestamp(comment.createdAt),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                comment.authorHandle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                comment.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Row(
                children: [
                  _buildLikeButton(comment),
                  const SizedBox(width: AppTheme.spacingS),
                  TextButton(
                    onPressed: () => _handleReplyTap(comment),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingXS,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Yanıtla',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }

  List<_CommentListItem> _buildCommentItems(List<CringeComment> comments) {
    if (comments.isEmpty) return const <_CommentListItem>[];

    final byId = <String, CringeComment>{
      for (final comment in comments) comment.id: comment,
    };

    final topLevel = <CringeComment>[];
    final replies = <String, List<CringeComment>>{};

    for (final comment in comments) {
      final parentId = comment.parentCommentId;
      if (parentId == null) {
        topLevel.add(comment);
      } else {
        replies.putIfAbsent(parentId, () => <CringeComment>[]).add(comment);
      }
    }

    topLevel.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final replyList in replies.values) {
      replyList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final visited = <String>{};
    final ordered = <_CommentListItem>[];

    void addWithChildren(CringeComment comment, int depth) {
      if (visited.contains(comment.id)) return;
      visited.add(comment.id);
      ordered.add(_CommentListItem(comment: comment, depth: depth));

      final children = replies[comment.id];
      if (children == null) return;
      for (final child in children) {
        addWithChildren(child, depth + 1);
      }
    }

    for (final comment in topLevel) {
      addWithChildren(comment, 0);
    }

    if (ordered.length < comments.length) {
      final remaining = comments.where((c) => !visited.contains(c.id)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final comment in remaining) {
        final depth = _calculateDepth(comment, byId);
        addWithChildren(comment, depth);
      }
    }

    return ordered;
  }

  int _calculateDepth(CringeComment comment, Map<String, CringeComment> byId) {
    var depth = 0;
    var current = comment;
    final visited = <String>{current.id};

    while (current.parentCommentId != null) {
      final parent = byId[current.parentCommentId!];
      if (parent == null || visited.contains(parent.id)) break;
      depth += 1;
      current = parent;
      visited.add(current.id);
    }

    return depth;
  }

  Widget _buildLikeButton(CringeComment comment) {
    final isLiked = _currentUserId != null &&
        comment.likedByUserIds.contains(_currentUserId);
    final isProcessing = _likingCommentIds.contains(comment.id);
    final icon = isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded;
    final color = isLiked ? AppTheme.cringeOrange : Colors.white.withValues(alpha: 0.7);

    return InkWell(
      onTap: isProcessing ? null : () => _handleToggleLike(comment),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isLiked
              ? AppTheme.cringeOrange.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isProcessing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              comment.likeCount.toString(),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReplyTap(CringeComment comment) {
    setState(() {
      _replyTarget = comment;
    });
    FocusScope.of(context).requestFocus(_composerFocusNode);
  }

  void _clearReplyTarget() {
    setState(() => _replyTarget = null);
  }

  Widget _buildReplyPreview() {
    final target = _replyTarget;
    if (target == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${target.authorName} kişisine yanıt veriyorsun',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: _clearReplyTarget,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 16,
          ),
        ],
      ),
    );
  }

  Future<void> _handleToggleLike(CringeComment comment) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beğeni için giriş yapmalısın.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_likingCommentIds.contains(comment.id)) return;

    setState(() {
      _likingCommentIds.add(comment.id);
    });

    final success = await CringeEntryService.instance.toggleCommentLike(
      entryId: widget.entry.id,
      commentId: comment.id,
    );

    if (!mounted) return;

    setState(() {
      _likingCommentIds.remove(comment.id);
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beğeni güncellenemedi. Tekrar deneyin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildComposer(BuildContext context) {
    final hintText = _replyTarget == null
        ? 'Yorum yaz...'
        : '${_replyTarget!.authorName} kişisine yanıt yaz...';

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyTarget != null) ...[
            _buildReplyPreview(),
            const SizedBox(height: AppTheme.spacingS),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _composerFocusNode,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.cringeOrange),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              SizedBox(
                width: 44,
                height: 44,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cringeOrange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir yorum yazın.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await CringeEntryService.instance.addComment(
      entryId: widget.entry.id,
      content: text,
      parentCommentId: _replyTarget?.id,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yorum gönderilemedi. Tekrar deneyin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _commentController.clear();
    FocusScope.of(context).unfocus();
    setState(() => _replyTarget = null);
    widget.onCommentAdded?.call();
  }

  String _buildInitials(String name, String handle) {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      final parts = trimmedName.split(RegExp(r'\s+'));
      final buffer = StringBuffer();
      for (final part in parts) {
        if (part.isEmpty) continue;
        buffer.write(part[0]);
        if (buffer.length == 2) break;
      }
      if (buffer.isNotEmpty) {
        return buffer.toString().toUpperCase();
      }
    }

    final normalizedHandle = handle.replaceAll('@', '').trim();
    if (normalizedHandle.length >= 2) {
      return normalizedHandle.substring(0, 2).toUpperCase();
    }

    return 'CR';
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'şimdi';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}dk';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}sa';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}g';
    }

    return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
  }
}

class _CommentListItem {
  final CringeComment comment;
  final int depth;

  const _CommentListItem({
    required this.comment,
    required this.depth,
  });
}
