using System;
using CringeBank.Domain.Auth.Enums;
using FluentValidation;

namespace CringeBank.Application.Admin;

public sealed class UpdateUserStatusCommandValidator : AbstractValidator<UpdateUserStatusCommand>
{
    public UpdateUserStatusCommandValidator()
    {
        RuleFor(command => command.ActorPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("actor_required");

        RuleFor(command => command.TargetPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("user_required");

        RuleFor(command => command.Status)
            .Must(status => Enum.IsDefined(typeof(AuthUserStatus), status))
            .WithMessage("status_invalid");
    }
}
