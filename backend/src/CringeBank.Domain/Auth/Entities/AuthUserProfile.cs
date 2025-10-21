using System;

namespace CringeBank.Domain.Auth.Entities;

public sealed partial class AuthUserProfile
{
    public long Id { get; private set; }

    public long UserId { get; private set; }

    public string? DisplayName { get; private set; }

    public string? Bio { get; private set; }

    public string? AvatarUrl { get; private set; }

    public string? BannerUrl { get; private set; }

    public bool Verified { get; private set; }

    public string? Location { get; private set; }

    public string? Website { get; private set; }

    public DateTime CreatedAt { get; private set; }

    public DateTime UpdatedAt { get; private set; }

    public AuthUser User { get; private set; } = null!;
}
