using System;
using FluentValidation;

namespace CringeBank.Application.Feeds;

public sealed class FeedSearchQueryValidator : AbstractValidator<FeedSearchQuery>
{
    private const int MaxPageSize = 100;

    public FeedSearchQueryValidator()
    {
        RuleFor(x => x.ViewerPublicId)
            .NotEqual(Guid.Empty)
            .WithMessage("Geçerli bir kullanıcı kimliği zorunludur.");

        RuleFor(x => x.Term)
            .NotEmpty()
            .MaximumLength(128)
            .WithMessage("Arama terimi boş olamaz ve 128 karakteri aşamaz.");

        RuleFor(x => x.PageSize)
            .GreaterThan(0)
            .LessThanOrEqualTo(MaxPageSize)
            .WithMessage($"Sayfa boyutu 1 ile {MaxPageSize} arasında olmalıdır.");
    }
}
