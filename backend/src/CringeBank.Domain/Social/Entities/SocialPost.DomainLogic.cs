using System;
using CringeBank.Domain.Social.Enums;
using CringeBank.Domain.ValueObjects;

namespace CringeBank.Domain.Social.Entities;

public sealed partial class SocialPost
{
    public static SocialPost Create(long userId, byte type, PostContent content, SocialPostVisibility visibility)
    {
        ArgumentNullException.ThrowIfNull(content);

        var utcNow = DateTime.UtcNow;

        var post = new SocialPost
        {
            PublicId = Guid.NewGuid(),
            UserId = userId,
            Type = type,
            Visibility = visibility,
            CreatedAt = utcNow,
            UpdatedAt = utcNow
        };

        post.SetContent(content);
        return post;
    }

    public PostContent ContentValueObject => PostContent.Create(Text);

    public void SetContent(PostContent content)
    {
        ArgumentNullException.ThrowIfNull(content);

        Text = content.Value;
        Touch();
    }

    public void SetVisibility(SocialPostVisibility visibility)
    {
        Visibility = visibility;
        Touch();
    }

    public void IncrementLikeCount() => LikesCount = Math.Max(0, LikesCount + 1);

    public void DecrementLikeCount() => LikesCount = Math.Max(0, LikesCount - 1);

    public void IncrementCommentCount() => CommentsCount = Math.Max(0, CommentsCount + 1);

    public void DecrementCommentCount() => CommentsCount = Math.Max(0, CommentsCount - 1);

    public void IncrementSaveCount() => SavesCount = Math.Max(0, SavesCount + 1);

    public void DecrementSaveCount() => SavesCount = Math.Max(0, SavesCount - 1);

    public void MarkDeleted(DateTime? utcNow = null)
    {
        DeletedAt = (utcNow ?? DateTime.UtcNow).ToUniversalTime();
        Touch(DeletedAt);
    }

    private void Touch(DateTime? utcNow = null)
    {
        UpdatedAt = (utcNow ?? DateTime.UtcNow).ToUniversalTime();
    }
}
