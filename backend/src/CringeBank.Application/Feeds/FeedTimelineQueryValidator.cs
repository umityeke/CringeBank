using System;
using FluentValidation;

namespace CringeBank.Application.Feeds;

public sealed class FeedTimelineQueryValidator : AbstractValidator<FeedTimelineQuery>
{
    private const int MaxPageSize = 100;

    public FeedTimelineQueryValidator()
    {
        RuleFor(x => x.ViewerPublicId)
            .NotEqual(Guid.Empty)
            .WithMessage("Geçerli bir kullanıcı kimliği zorunludur.");

        RuleFor(x => x.PageSize)
            .GreaterThan(0)
            .LessThanOrEqualTo(MaxPageSize)
            .WithMessage($"Sayfa boyutu 1 ile {MaxPageSize} arasında olmalıdır.");
    }
}
