using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Auth;

namespace CringeBank.Application.Auth.Commands;

public sealed class VerifyMfaCommandHandler : ICommandHandler<VerifyMfaCommand, VerifyMfaResult>
{
    private readonly IAuthUserRepository _repository;
    private readonly IMfaCodeValidator _mfaCodeValidator;
    private readonly IAuthTokenService _tokenService;

    public VerifyMfaCommandHandler(IAuthUserRepository repository, IMfaCodeValidator mfaCodeValidator, IAuthTokenService tokenService)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        _mfaCodeValidator = mfaCodeValidator ?? throw new ArgumentNullException(nameof(mfaCodeValidator));
        _tokenService = tokenService ?? throw new ArgumentNullException(nameof(tokenService));
    }

    public async Task<VerifyMfaResult> HandleAsync(VerifyMfaCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        if (!TokenUtility.TryParseToken(command.Token, out var publicId, out var codeBytes))
        {
            return VerifyFailure("invalid_token");
        }

        var user = await _repository.GetByPublicIdAsync(publicId, cancellationToken);

        if (user is null || user.Security is null || !user.Security.OtpEnabled || user.Security.OtpSecret is null)
        {
            return VerifyFailure("invalid_token");
        }

        var utcNow = DateTime.UtcNow;
        var hash = TokenUtility.ComputeSha256(codeBytes);

        if (!user.Security.IsMagicCodeValid(hash, utcNow))
        {
            return VerifyFailure("challenge_expired");
        }

        var code = command.Code?.Trim();
        if (string.IsNullOrWhiteSpace(code))
        {
            return VerifyFailure("invalid_code");
        }

        if (!_mfaCodeValidator.ValidateTotp(user.Security.OtpSecret, code, utcNow))
        {
            return VerifyFailure("invalid_code");
        }

        user.Security.ClearMagicCode();
        user.MarkSignedIn(utcNow);

        var tokens = _tokenService.CreateTokens(user, utcNow);
        user.Security.SetRefreshToken(tokens.RefreshToken.Hash, tokens.RefreshToken.ExpiresAtUtc);

        await _repository.SaveChangesAsync(cancellationToken);

        return new VerifyMfaResult(
            Success: true,
            AccessToken: tokens.AccessToken,
            RefreshToken: tokens.RefreshToken.Token,
            RefreshTokenExpiresAtUtc: tokens.RefreshToken.ExpiresAtUtc,
            FailureCode: null);
    }

    private static VerifyMfaResult VerifyFailure(string failureCode)
    {
        return new VerifyMfaResult(false, null, null, null, failureCode);
    }
}
