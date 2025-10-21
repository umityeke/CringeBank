using System;
using CringeBank.Domain.Auth.Entities;

namespace CringeBank.Application.Auth;

public interface IAuthTokenService
{
    AuthTokenPair CreateTokens(AuthUser user, DateTime utcNow);
    AuthTokenPair RefreshTokens(AuthUser user, DateTime utcNow, DateTime? currentRefreshExpiresAtUtc);
}

public sealed record AuthTokenPair(string AccessToken, RefreshToken RefreshToken);

public sealed record RefreshToken(string Token, DateTime ExpiresAtUtc, byte[] Hash);
