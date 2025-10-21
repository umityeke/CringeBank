using System;
using System.Collections.Generic;

namespace CringeBank.Application.Feeds;

public sealed record FeedItemResult(
    Guid PublicId,
    Guid AuthorPublicId,
    string AuthorUsername,
    string? AuthorDisplayName,
    string? AuthorAvatarUrl,
    string? Text,
    string Visibility,
    int LikesCount,
    int CommentsCount,
    int SavesCount,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    IReadOnlyList<FeedMediaItem> Media);
