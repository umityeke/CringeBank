using System;
using FluentValidation;

namespace CringeBank.Application.Chats;

public sealed class MarkConversationReadCommandValidator : AbstractValidator<MarkConversationReadCommand>
{
    public MarkConversationReadCommandValidator()
    {
        RuleFor(command => command.ConversationPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("conversation_required");

        RuleFor(command => command.UserPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("user_required");

        RuleFor(command => command.MessageId)
            .GreaterThan(0)
            .WithMessage("message_id_invalid");
    }
}
