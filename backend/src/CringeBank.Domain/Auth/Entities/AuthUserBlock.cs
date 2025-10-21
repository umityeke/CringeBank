using System;

namespace CringeBank.Domain.Auth.Entities;

public sealed class AuthUserBlock
{
    public long Id { get; private set; }

    public long BlockerUserId { get; private set; }

    public long BlockedUserId { get; private set; }

    public DateTime CreatedAt { get; private set; }

    public AuthUser Blocker { get; private set; } = null!;

    public AuthUser Blocked { get; private set; } = null!;
}
