using System;
using FluentValidation;

namespace CringeBank.Application.Wallet;

public sealed class ReleaseEscrowCommandValidator : AbstractValidator<ReleaseEscrowCommand>
{
    public ReleaseEscrowCommandValidator()
    {
        RuleFor(command => command.OrderPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("order_required");

        RuleFor(command => command.ActorPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("actor_required");
    }
}
