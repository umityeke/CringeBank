using System;
using System.Collections.Generic;

namespace CringeBank.Api.Chats;

public sealed record ConversationResponse(
    Guid PublicId,
    bool IsGroup,
    string? Title,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    IReadOnlyCollection<ConversationMemberResponse> Members);
