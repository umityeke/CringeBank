using System;

namespace CringeBank.Application.Auth;

public interface IPasswordHasher
{
    byte[] HashPassword(string password, ReadOnlySpan<byte> salt);

    bool VerifyPassword(string password, ReadOnlySpan<byte> salt, ReadOnlySpan<byte> hash);

    byte[] GenerateSalt(int size = 32);
}
