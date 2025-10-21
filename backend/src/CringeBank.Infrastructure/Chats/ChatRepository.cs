using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Chats;
using CringeBank.Domain.Chat.Entities;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CringeBank.Infrastructure.Chats;

public sealed class ChatRepository : IChatRepository
{
    private readonly CringeBankDbContext _dbContext;

    public ChatRepository(CringeBankDbContext dbContext)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
    }

    public void AddConversation(Conversation conversation)
    {
        ArgumentNullException.ThrowIfNull(conversation);
        _dbContext.Conversations.Add(conversation);
    }

    public Task<Conversation?> GetConversationWithMembersAsync(Guid conversationPublicId, CancellationToken cancellationToken = default)
    {
        if (conversationPublicId == Guid.Empty)
        {
            return Task.FromResult<Conversation?>(null);
        }

        return _dbContext.Conversations
            .Include(conversation => conversation.Members)
                .ThenInclude(member => member.User)
            .SingleOrDefaultAsync(conversation => conversation.PublicId == conversationPublicId, cancellationToken);
    }

    public Task<Message?> GetMessageInConversationAsync(Guid conversationPublicId, long messageId, CancellationToken cancellationToken = default)
    {
        if (conversationPublicId == Guid.Empty || messageId <= 0)
        {
            return Task.FromResult<Message?>(null);
        }

        return _dbContext.Messages
            .Include(message => message.Conversation)
            .Include(message => message.Sender)
            .Where(message => message.Id == messageId && message.Conversation.PublicId == conversationPublicId)
            .SingleOrDefaultAsync(cancellationToken);
    }

    public async Task<bool> IsConversationMemberAsync(Guid conversationPublicId, Guid userPublicId, CancellationToken cancellationToken = default)
    {
        if (conversationPublicId == Guid.Empty || userPublicId == Guid.Empty)
        {
            return false;
        }

        return await _dbContext.ConversationMembers
            .AnyAsync(member => member.Conversation.PublicId == conversationPublicId && member.User.PublicId == userPublicId, cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<Guid>> GetConversationMemberPublicIdsAsync(Guid conversationPublicId, CancellationToken cancellationToken = default)
    {
        if (conversationPublicId == Guid.Empty)
        {
            return Array.Empty<Guid>();
        }

        var identifiers = await _dbContext.ConversationMembers
            .Where(member => member.Conversation.PublicId == conversationPublicId)
            .Select(member => member.User.PublicId)
            .Distinct()
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return identifiers;
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return _dbContext.SaveChangesAsync(cancellationToken);
    }
}
