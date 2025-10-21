using System;
using CringeBank.Application.Abstractions.Queries;

namespace CringeBank.Application.Wallet;

public sealed record GetWalletBalanceQuery(Guid UserPublicId) : IQuery<WalletBalanceResult>;
