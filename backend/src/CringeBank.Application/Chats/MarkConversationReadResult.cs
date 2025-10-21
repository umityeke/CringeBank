using System;
using System.Collections.Generic;

namespace CringeBank.Application.Chats;

public sealed record MarkConversationReadResult(
    Guid ConversationPublicId,
    Guid UserPublicId,
    long LastReadMessageId,
    DateTime LastReadAt,
    IReadOnlyCollection<Guid> ParticipantPublicIds);
