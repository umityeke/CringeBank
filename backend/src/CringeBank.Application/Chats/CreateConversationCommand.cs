using System;
using System.Collections.Generic;
using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Chats;

public sealed record CreateConversationCommand(
    Guid InitiatorPublicId,
    bool IsGroup,
    string? Title,
    IReadOnlyCollection<Guid> ParticipantPublicIds) : ICommand<CreateConversationResult>;
