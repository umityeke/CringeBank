using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Auth.Commands;

public sealed class RevokeRefreshTokenCommandHandler : ICommandHandler<RevokeRefreshTokenCommand, RevokeRefreshTokenResult>
{
    private readonly IAuthUserRepository _repository;

    public RevokeRefreshTokenCommandHandler(IAuthUserRepository repository)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
    }

    public async Task<RevokeRefreshTokenResult> HandleAsync(RevokeRefreshTokenCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        if (!TokenUtility.TryParseToken(command.RefreshToken, out var publicId, out var codeBytes))
        {
            return Failure("invalid_token");
        }

        var user = await _repository.GetByPublicIdAsync(publicId, cancellationToken);
        if (user?.Security is null)
        {
            return Success();
        }

        var storedHash = user.Security.RefreshTokenHash;
        if (storedHash is null)
        {
            return Success();
        }

        var hash = TokenUtility.ComputeSha256(codeBytes);
        if (!storedHash.AsSpan().SequenceEqual(hash))
        {
            return Success();
        }

        user.Security.ClearRefreshToken();
        await _repository.SaveChangesAsync(cancellationToken);

        return Success();
    }

    private static RevokeRefreshTokenResult Success() => new(true, null);

    private static RevokeRefreshTokenResult Failure(string code) => new(false, code);
}
