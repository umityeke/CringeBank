using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Wallet;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Wallet.Entities;
using CringeBank.Domain.ValueObjects;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CringeBank.Infrastructure.Wallets;

public sealed class WalletRepository : IWalletRepository
{
    private const int CursorParts = 2;

    private readonly CringeBankDbContext _dbContext;

    public WalletRepository(CringeBankDbContext dbContext)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
    }

    public async Task<WalletAccount> EnsureAccountAsync(AuthUser user, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(user);

        var account = await _dbContext.WalletAccounts
            .SingleOrDefaultAsync(x => x.UserId == user.Id, cancellationToken)
            .ConfigureAwait(false);

        if (account is not null)
        {
            return account;
        }

        var currency = CurrencyCode.Create("CG");
        account = WalletAccount.Create(user.Id, currency);
        _dbContext.WalletAccounts.Add(account);
        await _dbContext.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return account;
    }

    public Task<WalletAccount?> GetAccountAsync(AuthUser user, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(user);

        return _dbContext.WalletAccounts
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.UserId == user.Id, cancellationToken);
    }

    public async Task<WalletTransactionPage> GetTransactionsAsync(long accountId, int pageSize, string? cursor, CancellationToken cancellationToken = default)
    {
        if (pageSize <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(pageSize));
        }

        var query = _dbContext.WalletTransactions
            .AsNoTracking()
            .Where(x => x.AccountId == accountId);

        if (!string.IsNullOrWhiteSpace(cursor) && TryDecodeCursor(cursor, out var createdAtTicks, out var lastId))
        {
            var createdAt = new DateTime(createdAtTicks, DateTimeKind.Utc);
            query = query.Where(x => x.CreatedAt < createdAt || (x.CreatedAt == createdAt && x.Id < lastId));
        }

        var items = await query
            .OrderByDescending(x => x.CreatedAt)
            .ThenByDescending(x => x.Id)
            .Take(pageSize + 1)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var hasMore = items.Count > pageSize;

        if (hasMore)
        {
            items.RemoveAt(items.Count - 1);
        }

        var nextCursor = hasMore && items.Count > 0
            ? EncodeCursor(items[^1])
            : null;

        return new WalletTransactionPage(items, nextCursor, hasMore);
    }

    private static string? EncodeCursor(WalletTransaction transaction)
    {
        var payload = string.Create(CultureInfo.InvariantCulture, $"{transaction.CreatedAt.Ticks}:{transaction.Id}");
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(payload));
    }

    private static bool TryDecodeCursor(string? cursor, out long createdAtTicks, out long transactionId)
    {
        createdAtTicks = 0;
        transactionId = 0;

        if (string.IsNullOrWhiteSpace(cursor))
        {
            return false;
        }

        try
        {
            var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(cursor));
            var segments = decoded.Split(':');

            if (segments.Length != CursorParts)
            {
                return false;
            }

            if (!long.TryParse(segments[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out createdAtTicks))
            {
                return false;
            }

            if (!long.TryParse(segments[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out transactionId))
            {
                createdAtTicks = 0;
                return false;
            }

            return true;
        }
        catch
        {
            createdAtTicks = 0;
            transactionId = 0;
            return false;
        }
    }
}
