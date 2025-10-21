using System;

namespace CringeBank.Api.Chats;

public sealed record ConversationMemberResponse(
    Guid UserPublicId,
    string Role,
    DateTime JoinedAt,
    long? LastReadMessageId,
    DateTime? LastReadAt);
