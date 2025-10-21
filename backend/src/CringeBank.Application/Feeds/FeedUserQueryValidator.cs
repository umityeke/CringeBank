using System;
using FluentValidation;

namespace CringeBank.Application.Feeds;

public sealed class FeedUserQueryValidator : AbstractValidator<FeedUserQuery>
{
    private const int MaxPageSize = 100;

    public FeedUserQueryValidator()
    {
        RuleFor(x => x.ViewerPublicId)
            .NotEqual(Guid.Empty)
            .WithMessage("Geçerli bir kullanıcı kimliği zorunludur.");

        RuleFor(x => x.TargetPublicId)
            .NotEqual(Guid.Empty)
            .WithMessage("Geçerli bir hedef kullanıcı kimliği zorunludur.");

        RuleFor(x => x.PageSize)
            .GreaterThan(0)
            .LessThanOrEqualTo(MaxPageSize)
            .WithMessage($"Sayfa boyutu 1 ile {MaxPageSize} arasında olmalıdır.");
    }
}
