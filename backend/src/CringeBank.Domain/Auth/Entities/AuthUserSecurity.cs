using System;

namespace CringeBank.Domain.Auth.Entities;

public sealed partial class AuthUserSecurity
{
    public long UserId { get; private set; }

    public byte[]? OtpSecret { get; private set; }

    public bool OtpEnabled { get; private set; }

    public byte[]? MagicCodeHash { get; private set; }

    public DateTime? MagicCodeExpiresAt { get; private set; }

    public byte[]? RefreshTokenHash { get; private set; }

    public DateTime? RefreshTokenExpiresAt { get; private set; }

    public DateTime? LastPasswordResetAt { get; private set; }

    public AuthUser User { get; private set; } = null!;
}
