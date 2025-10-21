using System;

namespace CringeBank.Domain.Social.Entities;

public sealed class SocialPostMedia
{
    public long Id { get; private set; }

    public long PostId { get; private set; }

    public string Url { get; private set; } = string.Empty;

    public string? Mime { get; private set; }

    public int? Width { get; private set; }

    public int? Height { get; private set; }

    public byte OrderIndex { get; private set; }

    public SocialPost Post { get; private set; } = null!;
}
