using System;
using System.Collections.Generic;
using CringeBank.Domain.Auth.Entities;

namespace CringeBank.Domain.Social.Entities;

public sealed class SocialPostComment
{
    private readonly List<SocialPostComment> _replies = new();
    private readonly List<SocialCommentLike> _likes = new();

    public long Id { get; private set; }

    public long PostId { get; private set; }

    public long? ParentCommentId { get; private set; }

    public long UserId { get; private set; }

    public string Text { get; private set; } = string.Empty;

    public int LikeCount { get; private set; }

    public DateTime CreatedAt { get; private set; }

    public DateTime UpdatedAt { get; private set; }

    public DateTime? DeletedAt { get; private set; }

    public SocialPost Post { get; private set; } = null!;

    public SocialPostComment? Parent { get; private set; }

    public AuthUser User { get; private set; } = null!;

    public IReadOnlyCollection<SocialPostComment> Replies => _replies;

    public IReadOnlyCollection<SocialCommentLike> Likes => _likes;
}
