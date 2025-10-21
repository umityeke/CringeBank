using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Auth;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Application.Wallet;

public sealed class RefundEscrowCommandHandler : ICommandHandler<RefundEscrowCommand, RefundEscrowResult>
{
    private readonly IAuthUserRepository _authUserRepository;
    private readonly IStoreEscrowGateway _escrowGateway;

    public RefundEscrowCommandHandler(
        IAuthUserRepository authUserRepository,
        IStoreEscrowGateway escrowGateway)
    {
        _authUserRepository = authUserRepository ?? throw new ArgumentNullException(nameof(authUserRepository));
        _escrowGateway = escrowGateway ?? throw new ArgumentNullException(nameof(escrowGateway));
    }

    public async Task<RefundEscrowResult> HandleAsync(RefundEscrowCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        var actor = await _authUserRepository.GetByPublicIdAsync(command.ActorPublicId, cancellationToken).ConfigureAwait(false);

        if (actor is null)
        {
            return RefundEscrowResult.Failure("actor_not_found");
        }

        if (!IsActive(actor))
        {
            return RefundEscrowResult.Failure("actor_not_active");
        }

        var authUid = actor.PublicId.ToString("N");
        var result = await _escrowGateway.RefundAsync(command.OrderPublicId, authUid, command.IsSystemOverride, command.RefundReason, cancellationToken).ConfigureAwait(false);

        return result.Success
            ? RefundEscrowResult.SuccessResult()
            : RefundEscrowResult.Failure(result.FailureCode ?? "escrow_failed", result.ErrorMessage);
    }

    private static bool IsActive(AuthUser user) => user.Status is AuthUserStatus.Active;
}
