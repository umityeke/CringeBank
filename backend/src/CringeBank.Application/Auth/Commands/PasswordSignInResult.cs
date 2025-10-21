namespace CringeBank.Application.Auth.Commands;

public sealed record PasswordSignInResult(
    bool Success,
    string? AccessToken,
    string? RefreshToken,
    DateTime? RefreshTokenExpiresAtUtc,
    bool RequiresMfa,
    string? MfaToken,
    string? FailureCode);
