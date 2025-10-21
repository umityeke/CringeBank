namespace CringeBank.Application.Auth.Commands;

public sealed record RefreshTokenResult(
    bool Success,
    string? AccessToken,
    string? RefreshToken,
    DateTime? RefreshTokenExpiresAtUtc,
    string? FailureCode);
