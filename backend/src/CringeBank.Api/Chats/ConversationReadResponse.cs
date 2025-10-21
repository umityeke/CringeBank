using System;
using System.Collections.Generic;

namespace CringeBank.Api.Chats;

public sealed record ConversationReadResponse(
    Guid ConversationPublicId,
    Guid UserPublicId,
    long LastReadMessageId,
    DateTime LastReadAt,
    IReadOnlyCollection<Guid> ParticipantPublicIds);
