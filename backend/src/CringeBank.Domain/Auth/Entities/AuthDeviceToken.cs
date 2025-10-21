using System;

namespace CringeBank.Domain.Auth.Entities;

public sealed class AuthDeviceToken
{
    public long Id { get; private set; }

    public long UserId { get; private set; }

    public string Platform { get; private set; } = string.Empty;

    public string Token { get; private set; } = string.Empty;

    public DateTime CreatedAt { get; private set; }

    public DateTime? LastUsedAt { get; private set; }

    public AuthUser User { get; private set; } = null!;
}
