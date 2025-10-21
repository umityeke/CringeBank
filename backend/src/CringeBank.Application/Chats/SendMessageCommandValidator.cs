using System;
using FluentValidation;

namespace CringeBank.Application.Chats;

public sealed class SendMessageCommandValidator : AbstractValidator<SendMessageCommand>
{
    public SendMessageCommandValidator()
    {
        RuleFor(command => command.ConversationPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("conversation_required");

        RuleFor(command => command.SenderPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("sender_required");

        RuleFor(command => command.Body)
            .NotEmpty()
            .WithMessage("body_required")
            .MaximumLength(2000)
            .WithMessage("body_too_long");
    }
}
