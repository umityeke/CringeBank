using System;

namespace CringeBank.Application.Feeds;

public sealed record FeedMediaItem(
    string Url,
    string? Mime,
    int? Width,
    int? Height,
    byte OrderIndex);
