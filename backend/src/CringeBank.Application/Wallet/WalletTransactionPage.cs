using System.Collections.Generic;
using CringeBank.Domain.Wallet.Entities;

namespace CringeBank.Application.Wallet;

public sealed record WalletTransactionPage(
    IReadOnlyCollection<WalletTransaction> Transactions,
    string? NextCursor,
    bool HasMore);
