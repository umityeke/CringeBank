using System;

namespace CringeBank.Application.Auth;

public interface IMfaCodeValidator
{
    bool ValidateTotp(ReadOnlySpan<byte> secret, string code, DateTime utcNow);
}
