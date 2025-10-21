using System;

namespace CringeBank.Domain.Auth.Entities;

public sealed class AuthLoginEvent
{
    public long Id { get; private set; }

    public long? UserId { get; private set; }

    public AuthUser? User { get; private set; }

    public string Identifier { get; private set; } = string.Empty;

    public DateTime EventAtUtc { get; private set; }

    public string Source { get; private set; } = string.Empty;

    public string Channel { get; private set; } = string.Empty;

    public string Result { get; private set; } = string.Empty;

    public string? DeviceIdHash { get; private set; }

    public string? IpHash { get; private set; }

    public string? UserAgent { get; private set; }

    public string? Locale { get; private set; }

    public string? TimeZone { get; private set; }

    public bool IsTrustedDevice { get; private set; }

    public bool RememberMe { get; private set; }

    public bool RequiresDeviceVerification { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }
}