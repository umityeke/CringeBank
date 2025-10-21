using System;
using System.Collections.Generic;

namespace CringeBank.Domain.Social.Entities;

public sealed class SocialTag
{
    private readonly List<SocialPostTag> _postTags = new();

    public long Id { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public DateTime CreatedAt { get; private set; }

    public IReadOnlyCollection<SocialPostTag> PostTags => _postTags;
}
