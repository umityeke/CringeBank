using System;
using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Chats;

public sealed record SendMessageCommand(
    Guid ConversationPublicId,
    Guid SenderPublicId,
    string Body) : ICommand<SendMessageResult>;
