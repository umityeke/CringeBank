using System;
using CringeBank.Domain.Chat.Enums;

namespace CringeBank.Application.Chats;

public sealed record ConversationMemberResult(
    Guid UserPublicId,
    ConversationMemberRole Role,
    DateTime JoinedAt,
    long? LastReadMessageId,
    DateTime? LastReadAt);
