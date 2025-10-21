using System;
using CringeBank.Application.Abstractions.Queries;

namespace CringeBank.Application.Feeds;

public sealed record FeedSearchQuery(
    Guid ViewerPublicId,
    string Term,
    int PageSize,
    string? Cursor) : IQuery<FeedCursorPage<FeedItemResult>>;
