using System;
using System.Security.Cryptography;

namespace CringeBank.Application.Auth;

public static class TokenUtility
{
    public static ChallengeToken GenerateChallengeToken(Guid publicId)
    {
        var randomBytes = RandomNumberGenerator.GetBytes(32);
        var payload = Convert.ToBase64String(randomBytes);
    var token = string.Concat(publicId.ToString("N"), ".", payload);

        return new ChallengeToken(token, randomBytes);
    }

    public static bool TryParseToken(string? token, out Guid publicId, out byte[]? codeBytes)
    {
        publicId = Guid.Empty;
        codeBytes = null;

        if (string.IsNullOrWhiteSpace(token))
        {
            return false;
        }

        var separatorIndex = token.IndexOf('.');
        if (separatorIndex <= 0 || separatorIndex >= token.Length - 1)
        {
            return false;
        }

        if (!Guid.TryParseExact(token.AsSpan(0, separatorIndex), "N", out publicId))
        {
            publicId = Guid.Empty;
            return false;
        }

        var payload = token[(separatorIndex + 1)..];
        try
        {
            codeBytes = Convert.FromBase64String(payload);
        }
        catch (FormatException)
        {
            codeBytes = null;
            return false;
        }

        return codeBytes is { Length: > 0 };
    }

    public static byte[] ComputeSha256(ReadOnlySpan<byte> bytes)
    {
        return SHA256.HashData(bytes);
    }
}

public readonly record struct ChallengeToken(string Token, byte[] CodePart);
