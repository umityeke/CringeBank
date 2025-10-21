using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Domain.Chat.Entities;

namespace CringeBank.Application.Chats;

public interface IChatRepository
{
    void AddConversation(Conversation conversation);

    Task<Conversation?> GetConversationWithMembersAsync(Guid conversationPublicId, CancellationToken cancellationToken = default);

    Task<Message?> GetMessageInConversationAsync(Guid conversationPublicId, long messageId, CancellationToken cancellationToken = default);

    Task<bool> IsConversationMemberAsync(Guid conversationPublicId, Guid userPublicId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Guid>> GetConversationMemberPublicIdsAsync(Guid conversationPublicId, CancellationToken cancellationToken = default);

    Task SaveChangesAsync(CancellationToken cancellationToken = default);
}
