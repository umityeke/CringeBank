using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Auth;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Application.Wallet;

public sealed class ReleaseEscrowCommandHandler : ICommandHandler<ReleaseEscrowCommand, ReleaseEscrowResult>
{
    private readonly IAuthUserRepository _authUserRepository;
    private readonly IStoreEscrowGateway _escrowGateway;

    public ReleaseEscrowCommandHandler(
        IAuthUserRepository authUserRepository,
        IStoreEscrowGateway escrowGateway)
    {
        _authUserRepository = authUserRepository ?? throw new ArgumentNullException(nameof(authUserRepository));
        _escrowGateway = escrowGateway ?? throw new ArgumentNullException(nameof(escrowGateway));
    }

    public async Task<ReleaseEscrowResult> HandleAsync(ReleaseEscrowCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        var actor = await _authUserRepository.GetByPublicIdAsync(command.ActorPublicId, cancellationToken).ConfigureAwait(false);

        if (actor is null)
        {
            return ReleaseEscrowResult.Failure("actor_not_found");
        }

        if (!IsActive(actor))
        {
            return ReleaseEscrowResult.Failure("actor_not_active");
        }

        var authUid = actor.PublicId.ToString("N");
        var result = await _escrowGateway.ReleaseAsync(command.OrderPublicId, authUid, command.IsSystemOverride, cancellationToken).ConfigureAwait(false);

        return result.Success
            ? ReleaseEscrowResult.SuccessResult()
            : ReleaseEscrowResult.Failure(result.FailureCode ?? "escrow_failed", result.ErrorMessage);
    }

    private static bool IsActive(AuthUser user) => user.Status is AuthUserStatus.Active;
}
