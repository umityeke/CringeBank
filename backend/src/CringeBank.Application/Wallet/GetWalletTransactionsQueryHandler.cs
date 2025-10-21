using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Queries;
using CringeBank.Application.Auth;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Auth.Enums;
using CringeBank.Domain.Wallet.Entities;
using CringeBank.Domain.Wallet.Enums;

namespace CringeBank.Application.Wallet;

public sealed class GetWalletTransactionsQueryHandler : IQueryHandler<GetWalletTransactionsQuery, WalletTransactionsPageResult>
{
    private readonly IAuthUserRepository _authUserRepository;
    private readonly IWalletRepository _walletRepository;

    public GetWalletTransactionsQueryHandler(
        IAuthUserRepository authUserRepository,
        IWalletRepository walletRepository)
    {
        _authUserRepository = authUserRepository ?? throw new ArgumentNullException(nameof(authUserRepository));
        _walletRepository = walletRepository ?? throw new ArgumentNullException(nameof(walletRepository));
    }

    public async Task<WalletTransactionsPageResult> HandleAsync(GetWalletTransactionsQuery query, CancellationToken cancellationToken)
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
        var page = await _walletRepository.GetTransactionsAsync(account.Id, query.PageSize, query.Cursor, cancellationToken).ConfigureAwait(false);

        var items = page.Transactions
            .Select(Map)
            .ToArray();

        return new WalletTransactionsPageResult(items, page.NextCursor, page.HasMore);
    }

    private static WalletTransactionResult Map(WalletTransaction transaction)
    {
    var type = Enum.GetName(typeof(WalletTransactionType), transaction.Type) ?? transaction.Type.ToString();

        return new WalletTransactionResult(
            transaction.Id,
            type,
            transaction.Amount,
            transaction.BalanceAfter,
            string.IsNullOrWhiteSpace(transaction.Reference) ? null : transaction.Reference,
            string.IsNullOrWhiteSpace(transaction.Metadata) ? null : transaction.Metadata,
            transaction.CreatedAt);
    }

    private static bool IsActive(AuthUser user) => user.Status is AuthUserStatus.Active;
}
