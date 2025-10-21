using System.Collections.Generic;

namespace CringeBank.Api.Wallet;

public sealed record WalletTransactionsResponse(
    IReadOnlyCollection<WalletTransactionResponse> Items,
    string? NextCursor,
    bool HasMore);
