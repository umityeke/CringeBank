using System;
using System.Collections.Generic;

namespace CringeBank.Api.Chats;

public sealed record MessageResponse(
    long Id,
    Guid ConversationPublicId,
    Guid SenderPublicId,
    string? Body,
    bool DeletedForAll,
    DateTime CreatedAt,
    DateTime? EditedAt,
    IReadOnlyCollection<Guid> ParticipantPublicIds);
