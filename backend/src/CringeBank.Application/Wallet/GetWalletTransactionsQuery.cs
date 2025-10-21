using System;
using CringeBank.Application.Abstractions.Queries;

namespace CringeBank.Application.Wallet;

public sealed record GetWalletTransactionsQuery(
    Guid UserPublicId,
    int PageSize,
    string? Cursor) : IQuery<WalletTransactionsPageResult>;
