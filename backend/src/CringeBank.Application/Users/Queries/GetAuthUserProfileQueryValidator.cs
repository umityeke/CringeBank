using System;
using FluentValidation;

namespace CringeBank.Application.Users.Queries;

public sealed class GetAuthUserProfileQueryValidator : AbstractValidator<GetAuthUserProfileQuery>
{
    public GetAuthUserProfileQueryValidator()
    {
        RuleFor(x => x.PublicId)
            .NotEqual(Guid.Empty)
            .WithMessage("PublicId boş olamaz.");
    }
}
