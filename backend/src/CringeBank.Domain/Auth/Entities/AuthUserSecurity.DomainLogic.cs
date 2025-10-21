using System;

namespace CringeBank.Domain.Auth.Entities;

public sealed partial class AuthUserSecurity
{
    public void SetMagicCode(byte[] hash, DateTime expiresAtUtc)
    {
        ArgumentNullException.ThrowIfNull(hash);

        MagicCodeHash = hash;
        MagicCodeExpiresAt = expiresAtUtc.ToUniversalTime();
    }

    public void ClearMagicCode()
    {
        MagicCodeHash = null;
        MagicCodeExpiresAt = null;
    }

    public bool IsMagicCodeValid(ReadOnlySpan<byte> hash, DateTime utcNow)
    {
        if (MagicCodeHash is null || MagicCodeExpiresAt is null)
        {
            return false;
        }

        if (MagicCodeExpiresAt.Value.ToUniversalTime() < utcNow.ToUniversalTime())
        {
            return false;
        }

        return MagicCodeHash.AsSpan().SequenceEqual(hash);
    }

    public void SetRefreshToken(byte[] hash, DateTime expiresAtUtc)
    {
        ArgumentNullException.ThrowIfNull(hash);

        RefreshTokenHash = hash;
        RefreshTokenExpiresAt = expiresAtUtc.ToUniversalTime();
    }

    public bool IsRefreshTokenValid(ReadOnlySpan<byte> hash, DateTime utcNow)
    {
        if (RefreshTokenHash is null || RefreshTokenExpiresAt is null)
        {
            return false;
        }

        if (RefreshTokenExpiresAt.Value.ToUniversalTime() < utcNow.ToUniversalTime())
        {
            return false;
        }

        return RefreshTokenHash.AsSpan().SequenceEqual(hash);
    }

    public void ClearRefreshToken()
    {
        RefreshTokenHash = null;
        RefreshTokenExpiresAt = null;
    }
}
