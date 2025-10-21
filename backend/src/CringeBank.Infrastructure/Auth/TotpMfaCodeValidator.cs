using System;
using CringeBank.Application.Auth;
using OtpNet;

namespace CringeBank.Infrastructure.Auth;

public sealed class TotpMfaCodeValidator : IMfaCodeValidator
{
    public bool ValidateTotp(ReadOnlySpan<byte> secret, string code, DateTime utcNow)
    {
        if (secret.IsEmpty)
        {
            return false;
        }

        var trimmed = code?.Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
        {
            return false;
        }

        try
        {
            var totp = new Totp(secret.ToArray());
            return totp.VerifyTotp(trimmed, out _, new VerificationWindow(previous: 1, future: 1));
        }
        catch
        {
            return false;
        }
    }
}
