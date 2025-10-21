using System;
using System.Collections.Generic;

namespace CringeBank.Api.Feeds;

public sealed record FeedItemResponse(
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
    IReadOnlyList<FeedMediaItemResponse> Media);
