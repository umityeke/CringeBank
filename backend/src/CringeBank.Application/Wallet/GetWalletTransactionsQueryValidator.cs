using System;
using FluentValidation;

namespace CringeBank.Application.Wallet;

public sealed class GetWalletTransactionsQueryValidator : AbstractValidator<GetWalletTransactionsQuery>
{
    private const int MaxPageSize = 100;

    public GetWalletTransactionsQueryValidator()
    {
        RuleFor(query => query.UserPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("user_required");

        RuleFor(query => query.PageSize)
            .InclusiveBetween(1, MaxPageSize)
            .WithMessage("page_size_invalid");
    }
}
