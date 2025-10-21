namespace CringeBank.Application.Auth.Commands;

public sealed record VerifyMfaResult(
    bool Success,
    string? AccessToken,
    string? RefreshToken,
    DateTime? RefreshTokenExpiresAtUtc,
    string? FailureCode);
