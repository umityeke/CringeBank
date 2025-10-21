using System;
using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Chats;

public sealed record MarkConversationReadCommand(
    Guid ConversationPublicId,
    Guid UserPublicId,
    long MessageId) : ICommand<MarkConversationReadCommandResult>;
