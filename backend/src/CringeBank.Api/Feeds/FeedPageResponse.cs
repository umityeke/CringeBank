using System.Collections.Generic;

namespace CringeBank.Api.Feeds;

public sealed record FeedPageResponse<TItem>(
    IReadOnlyList<TItem> Items,
    string? NextCursor,
    bool HasMore);
