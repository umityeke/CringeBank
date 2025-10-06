using System;

namespace CringeBank.Api.Authentication;

public sealed class FirebaseAuthenticationOptions
{
    public string ProjectId { get; init; } = string.Empty;

    public bool RequireEmailVerified { get; init; } = true;

    public bool CheckRevoked { get; init; } = true;

    public int MinimumClaimsVersion { get; init; } = 1;

    public string? ServiceAccountKeyPath { get; init; }

    public string? ServiceAccountJson { get; init; }

    public string? EmulatorHost { get; init; }

    public int TokenClockSkewMinutes { get; init; } = 2;

    public TimeSpan TokenClockSkew => TimeSpan.FromMinutes(Math.Clamp(TokenClockSkewMinutes, 0, 5));
}
