using System;
using CringeBank.Application.Abstractions.Queries;

namespace CringeBank.Application.Feeds;

public sealed record FeedTimelineQuery(
    Guid ViewerPublicId,
    int PageSize,
    string? Cursor) : IQuery<FeedCursorPage<FeedItemResult>>;
