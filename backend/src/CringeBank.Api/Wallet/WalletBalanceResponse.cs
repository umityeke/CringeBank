using System;

namespace CringeBank.Api.Wallet;

public sealed record WalletBalanceResponse(
    decimal Balance,
    string Currency,
    DateTime UpdatedAtUtc);
