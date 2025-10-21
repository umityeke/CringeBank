using System;
using System.Linq;
using CringeBank.Application.Wallet;

namespace CringeBank.Api.Wallet;

public static class WalletResponseMapper
{
    public static WalletBalanceResponse Map(WalletBalanceResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        return new WalletBalanceResponse(result.Balance, result.Currency, result.UpdatedAtUtc);
    }

    public static WalletTransactionsResponse Map(WalletTransactionsPageResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        var items = result.Items
            .Select(item => new WalletTransactionResponse(
                item.Id,
                item.Type,
                item.Amount,
                item.BalanceAfter,
                item.Reference,
                item.Metadata,
                item.CreatedAtUtc))
            .ToArray();

        return new WalletTransactionsResponse(items, result.NextCursor, result.HasMore);
    }
}
