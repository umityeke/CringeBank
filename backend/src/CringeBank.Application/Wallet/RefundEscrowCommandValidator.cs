using System;
using FluentValidation;

namespace CringeBank.Application.Wallet;

public sealed class RefundEscrowCommandValidator : AbstractValidator<RefundEscrowCommand>
{
    public RefundEscrowCommandValidator()
    {
        RuleFor(command => command.OrderPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("order_required");

        RuleFor(command => command.ActorPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("actor_required");

        RuleFor(command => command.RefundReason)
            .MaximumLength(256)
            .WithMessage("reason_too_long");
    }
}
