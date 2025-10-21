using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Auth;

namespace CringeBank.Application.Auth.Commands;

public sealed class RefreshTokenCommandHandler : ICommandHandler<RefreshTokenCommand, RefreshTokenResult>
{
    private readonly IAuthUserRepository _repository;
    private readonly IAuthTokenService _tokenService;

    public RefreshTokenCommandHandler(IAuthUserRepository repository, IAuthTokenService tokenService)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        _tokenService = tokenService ?? throw new ArgumentNullException(nameof(tokenService));
    }

    public async Task<RefreshTokenResult> HandleAsync(RefreshTokenCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        if (!TokenUtility.TryParseToken(command.RefreshToken, out var publicId, out var codeBytes))
        {
            return RefreshFailure("invalid_token");
        }

        var user = await _repository.GetByPublicIdAsync(publicId, cancellationToken);
        if (user is null || user.Security is null)
        {
            return RefreshFailure("invalid_token");
        }

        var utcNow = DateTime.UtcNow;
        var hash = TokenUtility.ComputeSha256(codeBytes);

        if (!user.Security.IsRefreshTokenValid(hash, utcNow))
        {
            return RefreshFailure("invalid_token");
        }

    var tokens = _tokenService.RefreshTokens(user, utcNow, user.Security.RefreshTokenExpiresAt);
        user.Security.SetRefreshToken(tokens.RefreshToken.Hash, tokens.RefreshToken.ExpiresAtUtc);
        user.Security.ClearMagicCode();

        await _repository.SaveChangesAsync(cancellationToken);

        return new RefreshTokenResult(
            Success: true,
            AccessToken: tokens.AccessToken,
            RefreshToken: tokens.RefreshToken.Token,
            RefreshTokenExpiresAtUtc: tokens.RefreshToken.ExpiresAtUtc,
            FailureCode: null);
    }

    private static RefreshTokenResult RefreshFailure(string failureCode)
    {
        return new RefreshTokenResult(false, null, null, null, failureCode);
    }
}
