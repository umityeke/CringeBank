namespace CringeBank.Api.Auth;

public sealed record PasswordSignInRequest(string Identifier, string Password, string? DeviceIdHash, string? IpHash);

public sealed record PasswordSignInResponse(
    bool Success,
    string? AccessToken,
    string? RefreshToken,
    DateTime? RefreshTokenExpiresAtUtc,
    bool RequiresMfa,
    string? MfaToken,
    string? FailureCode);

public sealed record RefreshTokenRequest(string RefreshToken);

public sealed record RefreshTokenResponse(
    bool Success,
    string? AccessToken,
    string? RefreshToken,
    DateTime? RefreshTokenExpiresAtUtc,
    string? FailureCode);

public sealed record RevokeRefreshTokenRequest(string RefreshToken);

public sealed record RevokeRefreshTokenResponse(bool Success, string? FailureCode);

public sealed record SendMagicLinkRequest(string Email);

public sealed record SendMagicLinkResponse(bool Sent, string? DebugToken);

public sealed record RedeemMagicLinkRequest(string Token);

public sealed record RedeemMagicLinkResponse(
    bool Success,
    string? AccessToken,
    string? RefreshToken,
    DateTime? RefreshTokenExpiresAtUtc,
    string? FailureCode);

public sealed record VerifyMfaRequest(string Token, string Code);

public sealed record VerifyMfaResponse(
    bool Success,
    string? AccessToken,
    string? RefreshToken,
    DateTime? RefreshTokenExpiresAtUtc,
    string? FailureCode);
