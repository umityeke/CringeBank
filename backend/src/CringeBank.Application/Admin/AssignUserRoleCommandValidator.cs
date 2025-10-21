using System;
using FluentValidation;

namespace CringeBank.Application.Admin;

public sealed class AssignUserRoleCommandValidator : AbstractValidator<AssignUserRoleCommand>
{
    public AssignUserRoleCommandValidator()
    {
        RuleFor(command => command.ActorPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("actor_required");

        RuleFor(command => command.TargetPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("user_required");

        RuleFor(command => command.RoleName)
            .NotEmpty()
            .WithMessage("role_required")
            .MaximumLength(128)
            .WithMessage("role_too_long");
    }
}
