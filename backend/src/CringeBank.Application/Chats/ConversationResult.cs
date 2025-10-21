using System;
using System.Collections.Generic;

namespace CringeBank.Application.Chats;

public sealed record ConversationResult(
    Guid PublicId,
    bool IsGroup,
    string? Title,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    IReadOnlyCollection<ConversationMemberResult> Members);
