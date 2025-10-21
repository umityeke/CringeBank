using System;
using System.Collections.Generic;

namespace CringeBank.Application.Chats;

public sealed record MessageResult(
    long Id,
    Guid ConversationPublicId,
    Guid SenderPublicId,
    string? Body,
    bool DeletedForAll,
    DateTime CreatedAt,
    DateTime? EditedAt,
    IReadOnlyCollection<Guid> ParticipantPublicIds);
