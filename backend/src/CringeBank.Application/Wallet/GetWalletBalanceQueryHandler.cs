using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Queries;
using CringeBank.Application.Auth;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Application.Wallet;

public sealed class GetWalletBalanceQueryHandler : IQueryHandler<GetWalletBalanceQuery, WalletBalanceResult>
{
    private readonly IAuthUserRepository _authUserRepository;
    private readonly IWalletRepository _walletRepository;

    public GetWalletBalanceQueryHandler(
        IAuthUserRepository authUserRepository,
        IWalletRepository walletRepository)
    {
        _authUserRepository = authUserRepository ?? throw new ArgumentNullException(nameof(authUserRepository));
        _walletRepository = walletRepository ?? throw new ArgumentNullException(nameof(walletRepository));
    }

    public async Task<WalletBalanceResult> HandleAsync(GetWalletBalanceQuery query, CancellationToken cancellationToken)
    {
        if (query is null)
        {
            throw new ArgumentNullException(nameof(query));
        }

        var user = await _authUserRepository.GetByPublicIdAsync(query.UserPublicId, cancellationToken).ConfigureAwait(false);

        if (user is null)
        {
            throw new InvalidOperationException("User not found.");
        }

        if (!IsActive(user))
        {
            throw new InvalidOperationException("User is not active.");
        }

        var account = await _walletRepository.EnsureAccountAsync(user, cancellationToken).ConfigureAwait(false);

        return new WalletBalanceResult(
            account.Balance,
            account.Currency,
            account.UpdatedAt);
    }

    private static bool IsActive(AuthUser user) => user.Status is AuthUserStatus.Active;
}
