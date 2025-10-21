using System;
using CringeBank.Application.Abstractions.Queries;

namespace CringeBank.Application.Feeds;

public sealed record FeedUserQuery(
    Guid ViewerPublicId,
    Guid TargetPublicId,
    int PageSize,
    string? Cursor) : IQuery<FeedCursorPage<FeedItemResult>>;
