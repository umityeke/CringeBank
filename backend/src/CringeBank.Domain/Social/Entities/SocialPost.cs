using System;
using System.Collections.Generic;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Social.Enums;

namespace CringeBank.Domain.Social.Entities;

public sealed partial class SocialPost
{
    private readonly List<SocialPostMedia> _media = new();
    private readonly List<SocialPostLike> _likes = new();
    private readonly List<SocialPostComment> _comments = new();
    private readonly List<SocialPostSave> _saves = new();
    private readonly List<SocialPostTag> _tags = new();

    public long Id { get; private set; }

    public Guid PublicId { get; private set; }

    public long UserId { get; private set; }

    public byte Type { get; private set; }

    public string? Text { get; private set; }

    public SocialPostVisibility Visibility { get; private set; } = SocialPostVisibility.Public;

    public int LikesCount { get; private set; }

    public int CommentsCount { get; private set; }

    public int SavesCount { get; private set; }

    public DateTime CreatedAt { get; private set; }

    public DateTime UpdatedAt { get; private set; }

    public DateTime? DeletedAt { get; private set; }

    public AuthUser Author { get; private set; } = null!;

    public IReadOnlyCollection<SocialPostMedia> Media => _media;

    public IReadOnlyCollection<SocialPostLike> Likes => _likes;

    public IReadOnlyCollection<SocialPostComment> Comments => _comments;

    public IReadOnlyCollection<SocialPostSave> Saves => _saves;

    public IReadOnlyCollection<SocialPostTag> Tags => _tags;
}
