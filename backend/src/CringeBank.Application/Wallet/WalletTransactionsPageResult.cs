using System.Collections.Generic;

namespace CringeBank.Application.Wallet;

public sealed record WalletTransactionsPageResult(
    IReadOnlyCollection<WalletTransactionResult> Items,
    string? NextCursor,
    bool HasMore);
