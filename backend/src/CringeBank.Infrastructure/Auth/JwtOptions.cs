using System;
using System.Collections.Generic;

namespace CringeBank.Infrastructure.Auth;

public sealed class JwtOptions
{
    public string Issuer { get; set; } = string.Empty;

    public string Audience { get; set; } = string.Empty;

    public int AccessMinutes { get; set; } = 15;

    public int RefreshDays { get; set; } = 30;

    public int RefreshSlidingMinutes { get; set; } = 240;

    public bool AllowEphemeralSigningKey { get; set; }

    public IList<JwtKeyOptions> Keys { get; } = new List<JwtKeyOptions>();
}

public sealed class JwtKeyOptions
{
    public string KeyId { get; set; } = string.Empty;

    public bool IsPrimary { get; set; }

    public string Type { get; set; } = "rsa";

    public string? PrivateKey { get; set; }

    public string? PrivateKeyEnvironmentVariable { get; set; }

    public string? PublicKey { get; set; }

    public string? PublicKeyEnvironmentVariable { get; set; }

    public DateTimeOffset? NotBefore { get; set; }

    public DateTimeOffset? NotAfter { get; set; }
}
