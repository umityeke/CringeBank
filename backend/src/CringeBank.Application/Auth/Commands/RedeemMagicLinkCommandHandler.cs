using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Auth;

namespace CringeBank.Application.Auth.Commands;

public sealed class RedeemMagicLinkCommandHandler : ICommandHandler<RedeemMagicLinkCommand, RedeemMagicLinkResult>
{
    private readonly IAuthUserRepository _repository;
    private readonly IAuthTokenService _tokenService;

    public RedeemMagicLinkCommandHandler(IAuthUserRepository repository, IAuthTokenService tokenService)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        _tokenService = tokenService ?? throw new ArgumentNullException(nameof(tokenService));
    }

    public async Task<RedeemMagicLinkResult> HandleAsync(RedeemMagicLinkCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        if (!TokenUtility.TryParseToken(command.Token, out var publicId, out var codeBytes))
        {
            return RedeemFailure("invalid_token");
        }

        var user = await _repository.GetByPublicIdAsync(publicId, cancellationToken);

        if (user is null || user.Security is null)
        {
            return RedeemFailure("invalid_token");
        }

        var utcNow = DateTime.UtcNow;
        var hash = TokenUtility.ComputeSha256(codeBytes);

        if (!user.Security.IsMagicCodeValid(hash, utcNow))
        {
            return RedeemFailure("invalid_token");
        }

        user.Security.ClearMagicCode();
        user.MarkSignedIn(utcNow);

        var tokens = _tokenService.CreateTokens(user, utcNow);
        user.Security.SetRefreshToken(tokens.RefreshToken.Hash, tokens.RefreshToken.ExpiresAtUtc);

        await _repository.SaveChangesAsync(cancellationToken);

        return new RedeemMagicLinkResult(
            Success: true,
            AccessToken: tokens.AccessToken,
            RefreshToken: tokens.RefreshToken.Token,
            RefreshTokenExpiresAtUtc: tokens.RefreshToken.ExpiresAtUtc,
            FailureCode: null);
    }

    private static RedeemMagicLinkResult RedeemFailure(string failureCode)
    {
        return new RedeemMagicLinkResult(false, null, null, null, failureCode);
    }
}
