using System;
using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Wallet;

public interface IStoreEscrowGateway
{
    Task<EscrowOperationResult> ReleaseAsync(Guid orderPublicId, string actorAuthUid, bool isSystemOverride, CancellationToken cancellationToken = default);

    Task<EscrowOperationResult> RefundAsync(Guid orderPublicId, string actorAuthUid, bool isSystemOverride, string? refundReason, CancellationToken cancellationToken = default);
}
