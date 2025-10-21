namespace CringeBank.Api.Feeds;

public sealed record FeedMediaItemResponse(
    string Url,
    string? Mime,
    int? Width,
    int? Height,
    byte OrderIndex);
