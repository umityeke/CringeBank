using System;
using System.Collections.Generic;
using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using CringeBank.Application.Auth;
using CringeBank.Domain.Auth.Entities;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace CringeBank.Infrastructure.Auth;

public sealed class AuthTokenService : IAuthTokenService
{
    private readonly IOptions<JwtOptions> _options;

    public AuthTokenService(IOptions<JwtOptions> options)
    {
        _options = options ?? throw new ArgumentNullException(nameof(options));
    }

    public AuthTokenPair CreateTokens(AuthUser user, DateTime utcNow)
    {
        ArgumentNullException.ThrowIfNull(user);

        var options = GetValidatedOptions();
        var accessToken = CreateAccessToken(user, utcNow, options);
        var refreshToken = CreateRefreshToken(user, utcNow, options, null);

        return new AuthTokenPair(accessToken, refreshToken);
    }

    public AuthTokenPair RefreshTokens(AuthUser user, DateTime utcNow, DateTime? currentRefreshExpiresAtUtc)
    {
        ArgumentNullException.ThrowIfNull(user);

        var options = GetValidatedOptions();
        var accessToken = CreateAccessToken(user, utcNow, options);
        var refreshToken = CreateRefreshToken(user, utcNow, options, currentRefreshExpiresAtUtc);

        return new AuthTokenPair(accessToken, refreshToken);
    }

    private static string CreateAccessToken(AuthUser user, DateTime utcNow, JwtOptions options)
    {
        var signingCredentials = CreateSigningCredentials(options);
        var expires = utcNow.AddMinutes(options.AccessMinutes);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.PublicId.ToString("N")),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(JwtRegisteredClaimNames.Iat, new DateTimeOffset(utcNow).ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture)),
            new("uid", user.PublicId.ToString()),
            new("status", user.Status.ToString())
        };

        if (!string.IsNullOrWhiteSpace(user.Email))
        {
            claims.Add(new Claim(JwtRegisteredClaimNames.Email, user.Email));
        }

        if (!string.IsNullOrWhiteSpace(user.Username))
        {
            claims.Add(new Claim("preferred_username", user.Username));
        }

        if (user.Security?.OtpEnabled == true)
        {
            claims.Add(new Claim("mfa", "true"));
        }

        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = options.Issuer,
            Audience = options.Audience,
            Subject = new ClaimsIdentity(claims),
            Expires = expires,
            NotBefore = utcNow,
            IssuedAt = utcNow,
            SigningCredentials = signingCredentials
        };

        var handler = new JwtSecurityTokenHandler();
        var token = handler.CreateToken(descriptor);
        return handler.WriteToken(token);
    }

    private static RefreshToken CreateRefreshToken(AuthUser user, DateTime utcNow, JwtOptions options, DateTime? currentRefreshExpiresAtUtc)
    {
        var expiresAtUtc = CalculateRefreshTokenExpiration(options, utcNow, currentRefreshExpiresAtUtc);
        var challenge = TokenUtility.GenerateChallengeToken(user.PublicId);
        var hash = TokenUtility.ComputeSha256(challenge.CodePart);

        return new RefreshToken(challenge.Token, expiresAtUtc, hash);
    }

    private JwtOptions GetValidatedOptions()
    {
        var options = _options.Value;

        if (options.Keys.Count == 0)
        {
            throw new InvalidOperationException("Jwt anahtarları yapılandırılmadı.");
        }

        return options;
    }

    private static SigningCredentials CreateSigningCredentials(JwtOptions options)
    {
        var keyOptions = options.Keys.FirstOrDefault(k => k.IsPrimary) ?? options.Keys[0];

        ValidateKeyWindow(keyOptions);

        var securityKey = BuildSecurityKey(keyOptions);
        var algorithm = ResolveAlgorithm(keyOptions.Type);

        if (!string.IsNullOrWhiteSpace(keyOptions.KeyId))
        {
            securityKey.KeyId = keyOptions.KeyId;
        }

        return new SigningCredentials(securityKey, algorithm);
    }

    private static void ValidateKeyWindow(JwtKeyOptions keyOptions)
    {
        var now = DateTimeOffset.UtcNow;

        if (keyOptions.NotBefore.HasValue && now < keyOptions.NotBefore.Value)
        {
            throw new InvalidOperationException($"JWT anahtarı ({keyOptions.KeyId}) henüz geçerli değil.");
        }

        if (keyOptions.NotAfter.HasValue && now > keyOptions.NotAfter.Value)
        {
            throw new InvalidOperationException($"JWT anahtarı ({keyOptions.KeyId}) süresi dolmuş.");
        }
    }

    private static string ResolveAlgorithm(string? type)
    {
        return type?.ToLowerInvariant() switch
        {
            "rsa" or "rs256" => SecurityAlgorithms.RsaSha256,
            "hmac" or "hs256" or "shared" or "symmetric" => SecurityAlgorithms.HmacSha256,
            _ => throw new InvalidOperationException($"Desteklenmeyen JWT anahtar tipi: {type ?? "(null)"}.")
        };
    }

    private static SecurityKey BuildSecurityKey(JwtKeyOptions keyOptions)
    {
        var keyMaterial = ResolvePrivateKeyMaterial(keyOptions);

        return keyOptions.Type?.ToLowerInvariant() switch
        {
            "rsa" or "rs256" => BuildRsaSecurityKey(keyMaterial),
            "hmac" or "hs256" or "shared" or "symmetric" or null => BuildSymmetricSecurityKey(keyMaterial),
            _ => throw new InvalidOperationException($"Desteklenmeyen JWT anahtar tipi: {keyOptions.Type}.")
        };
    }

    private static DateTime CalculateRefreshTokenExpiration(JwtOptions options, DateTime utcNow, DateTime? currentRefreshExpiresAtUtc)
    {
        var absoluteExpiry = utcNow.AddDays(options.RefreshDays);

        if (currentRefreshExpiresAtUtc is null)
        {
            return absoluteExpiry;
        }

        if (currentRefreshExpiresAtUtc.Value <= utcNow)
        {
            return absoluteExpiry;
        }

        if (options.RefreshSlidingMinutes <= 0)
        {
            return currentRefreshExpiresAtUtc.Value;
        }

        var threshold = TimeSpan.FromMinutes(options.RefreshSlidingMinutes);
        var remaining = currentRefreshExpiresAtUtc.Value - utcNow;

        return remaining <= threshold ? absoluteExpiry : currentRefreshExpiresAtUtc.Value;
    }

    private static RsaSecurityKey BuildRsaSecurityKey(string keyMaterial)
    {
        try
        {
            using var rsa = RSA.Create();

            if (ContainsPemHeader(keyMaterial))
            {
                rsa.ImportFromPem(keyMaterial);
            }
            else
            {
                var keyBytes = Convert.FromBase64String(keyMaterial);
                rsa.ImportPkcs8PrivateKey(keyBytes, out _);
            }

            return new RsaSecurityKey(rsa.ExportParameters(true));
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException("RSA imza anahtarı yüklenemedi.", ex);
        }
    }

    private static SymmetricSecurityKey BuildSymmetricSecurityKey(string keyMaterial)
    {
        var keyBytes = TryBase64Decode(keyMaterial, out var decoded)
            ? decoded
            : Encoding.UTF8.GetBytes(keyMaterial);

        if (keyBytes.Length < 32)
        {
            throw new InvalidOperationException("JWT HMAC anahtarı en az 256 bit olmalıdır.");
        }

        return new SymmetricSecurityKey(keyBytes);
    }

    private static string ResolvePrivateKeyMaterial(JwtKeyOptions keyOptions)
    {
        if (!string.IsNullOrWhiteSpace(keyOptions.PrivateKey))
        {
            return keyOptions.PrivateKey;
        }

        if (!string.IsNullOrWhiteSpace(keyOptions.PrivateKeyEnvironmentVariable))
        {
            var envValue = Environment.GetEnvironmentVariable(keyOptions.PrivateKeyEnvironmentVariable);
            if (!string.IsNullOrWhiteSpace(envValue))
            {
                return envValue;
            }

            throw new InvalidOperationException($"Environment {keyOptions.PrivateKeyEnvironmentVariable} boş. JWT anahtarı yüklenemedi.");
        }

        throw new InvalidOperationException($"JWT imza anahtarı ({keyOptions.KeyId}) bulunamadı.");
    }

    private static bool TryBase64Decode(string value, out byte[] bytes)
    {
        try
        {
            bytes = Convert.FromBase64String(value);
            return true;
        }
        catch (FormatException)
        {
            bytes = Array.Empty<byte>();
            return false;
        }
    }

    private static bool ContainsPemHeader(string value)
    {
        return value.Contains("BEGIN", StringComparison.OrdinalIgnoreCase);
    }
}
