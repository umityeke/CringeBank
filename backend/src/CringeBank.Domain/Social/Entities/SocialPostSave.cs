using System;
using CringeBank.Domain.Auth.Entities;

namespace CringeBank.Domain.Social.Entities;

public sealed class SocialPostSave
{
    public long Id { get; private set; }

    public long PostId { get; private set; }

    public long UserId { get; private set; }

    public DateTime CreatedAt { get; private set; }

    public SocialPost Post { get; private set; } = null!;

    public AuthUser User { get; private set; } = null!;
}
