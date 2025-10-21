using System;
using FluentValidation;

namespace CringeBank.Application.Wallet;

public sealed class GetWalletBalanceQueryValidator : AbstractValidator<GetWalletBalanceQuery>
{
    public GetWalletBalanceQueryValidator()
    {
        RuleFor(query => query.UserPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("user_required");
    }
}
