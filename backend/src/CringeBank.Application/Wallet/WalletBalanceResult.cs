using System;

namespace CringeBank.Application.Wallet;

public sealed record WalletBalanceResult(
    decimal Balance,
    string Currency,
    DateTime UpdatedAtUtc);
