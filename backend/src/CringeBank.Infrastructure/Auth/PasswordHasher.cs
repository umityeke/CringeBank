using System;
using System.Security.Cryptography;
using CringeBank.Application.Auth;

namespace CringeBank.Infrastructure.Auth;

public sealed class PasswordHasher : IPasswordHasher
{
    private const int Iterations = 100_000;

    public byte[] GenerateSalt(int size = 32)
    {
        if (size <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(size));
        }

        var salt = new byte[size];
        RandomNumberGenerator.Fill(salt);
        return salt;
    }

    public byte[] HashPassword(string password, ReadOnlySpan<byte> salt)
    {
        if (string.IsNullOrEmpty(password))
        {
            throw new ArgumentException("Parola boş olamaz.", nameof(password));
        }

        if (salt.IsEmpty)
        {
            throw new ArgumentException("Salt boş olamaz.", nameof(salt));
        }

        return Rfc2898DeriveBytes.Pbkdf2(password, salt, Iterations, HashAlgorithmName.SHA256, 32);
    }

    public bool VerifyPassword(string password, ReadOnlySpan<byte> salt, ReadOnlySpan<byte> hash)
    {
        if (hash.IsEmpty)
        {
            return false;
        }

        var computed = HashPassword(password, salt);
        return CryptographicOperations.FixedTimeEquals(computed, hash);
    }
}
