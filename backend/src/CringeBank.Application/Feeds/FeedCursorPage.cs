using System.Collections.Generic;

namespace CringeBank.Application.Feeds;

public sealed record FeedCursorPage<TItem>(
    IReadOnlyList<TItem> Items,
    string? NextCursor,
    bool HasMore);
