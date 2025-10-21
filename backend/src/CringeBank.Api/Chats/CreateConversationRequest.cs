using System;
using System.Collections.Generic;

namespace CringeBank.Api.Chats;

public sealed class CreateConversationRequest
{
    public bool IsGroup { get; set; }

    public string? Title { get; set; }

    public List<Guid> ParticipantPublicIds { get; set; } = new();
}
