using System;
using System.Collections.Generic;
using System.Linq;
using FluentValidation;

namespace CringeBank.Application.Chats;

public sealed class CreateConversationCommandValidator : AbstractValidator<CreateConversationCommand>
{
    public CreateConversationCommandValidator()
    {
        RuleFor(command => command.InitiatorPublicId)
            .Must(id => id != Guid.Empty)
            .WithMessage("initiator_required");

        RuleFor(command => command.ParticipantPublicIds)
            .NotNull()
            .Must(participants => participants is { Count: > 0 })
            .WithMessage("participants_required");

        RuleFor(command => command)
            .Must(HasValidParticipantCount)
            .WithMessage("participants_invalid");

        RuleFor(command => command)
            .Must(command => command.ParticipantPublicIds.All(id => id != command.InitiatorPublicId))
            .WithMessage("participants_cannot_include_initiator");

        RuleFor(command => command.ParticipantPublicIds)
            .Must(participants => participants.Count == participants.Distinct().Count())
            .WithMessage("participants_must_be_unique");

        RuleFor(command => command.Title)
            .Must(title => string.IsNullOrWhiteSpace(title) || title.Trim().Length <= 128)
            .WithMessage("title_too_long");
    }

    private static bool HasValidParticipantCount(CreateConversationCommand command)
    {
        if (command.ParticipantPublicIds is null)
        {
            return false;
        }

        var count = command.ParticipantPublicIds.Count;
        return command.IsGroup ? count >= 2 : count == 1;
    }
}
