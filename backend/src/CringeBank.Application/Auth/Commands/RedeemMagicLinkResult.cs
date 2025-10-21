namespace CringeBank.Application.Auth.Commands;

public sealed record RedeemMagicLinkResult(
    bool Success,
    string? AccessToken,
    string? RefreshToken,
    DateTime? RefreshTokenExpiresAtUtc,
    string? FailureCode);
