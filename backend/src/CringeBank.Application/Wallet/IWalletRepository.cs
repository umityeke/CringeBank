using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Wallet.Entities;

namespace CringeBank.Application.Wallet;

public interface IWalletRepository
{
    Task<WalletAccount> EnsureAccountAsync(AuthUser user, CancellationToken cancellationToken = default);

    Task<WalletAccount?> GetAccountAsync(AuthUser user, CancellationToken cancellationToken = default);

    Task<WalletTransactionPage> GetTransactionsAsync(long accountId, int pageSize, string? cursor, CancellationToken cancellationToken = default);
}
