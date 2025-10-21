using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Chats;
using CringeBank.Application.Notifications;
using Microsoft.AspNetCore.SignalR;

namespace CringeBank.Api.Chats;

public sealed class SignalRChatEventPublisher : IChatEventPublisher
{
    private readonly IHubContext<ChatHub> _hubContext;
    private readonly IChatNotificationService _chatNotificationService;

    public SignalRChatEventPublisher(IHubContext<ChatHub> hubContext, IChatNotificationService chatNotificationService)
    {
        _hubContext = hubContext ?? throw new ArgumentNullException(nameof(hubContext));
        _chatNotificationService = chatNotificationService ?? throw new ArgumentNullException(nameof(chatNotificationService));
    }

    public Task PublishConversationCreatedAsync(ConversationResult conversation, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(conversation);

        var payload = ChatResponseMapper.Map(conversation);
        var recipients = conversation.Members
            .Select(member => member.UserPublicId)
            .Where(id => id != Guid.Empty)
            .Distinct()
            .ToArray();

        return BroadcastToUsers(recipients, "ChatConversationCreated", payload, cancellationToken);
    }

    public async Task PublishMessageSentAsync(MessageResult message, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(message);

        var payload = ChatResponseMapper.Map(message);
        var recipients = message.ParticipantPublicIds
            .Where(id => id != Guid.Empty)
            .Distinct()
            .ToArray();

        var userBroadcast = BroadcastToUsers(recipients, "ChatMessageSent", payload, cancellationToken);
        var conversationBroadcast = _hubContext
            .Clients
            .Group(ChatHub.GetConversationGroupName(message.ConversationPublicId))
            .SendAsync("ChatMessageSent", payload, cancellationToken);
        var notificationTask = _chatNotificationService.QueueAsync(message, cancellationToken);

        await Task.WhenAll(userBroadcast, conversationBroadcast, notificationTask).ConfigureAwait(false);
    }

    public async Task PublishConversationReadAsync(MarkConversationReadResult result, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(result);

        var payload = ChatResponseMapper.Map(result);
        var recipients = result.ParticipantPublicIds
            .Where(id => id != Guid.Empty)
            .Distinct()
            .ToArray();

        var userBroadcast = BroadcastToUsers(recipients, "ChatConversationRead", payload, cancellationToken);
        var conversationBroadcast = _hubContext
            .Clients
            .Group(ChatHub.GetConversationGroupName(result.ConversationPublicId))
            .SendAsync("ChatConversationRead", payload, cancellationToken);

        await Task.WhenAll(userBroadcast, conversationBroadcast).ConfigureAwait(false);
    }

    private Task BroadcastToUsers(IEnumerable<Guid> userIds, string method, object payload, CancellationToken cancellationToken)
    {
        var tasks = userIds
            .Select(id => _hubContext.Clients.Group(ChatHub.GetUserGroupName(id)).SendAsync(method, payload, cancellationToken));
        return Task.WhenAll(tasks);
    }
}
