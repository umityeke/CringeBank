using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Chats;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace CringeBank.Api.Chats;

[Authorize]
public sealed class ChatHub : Hub
{
    private readonly IChatRepository _chatRepository;

    public ChatHub(IChatRepository chatRepository)
    {
        _chatRepository = chatRepository ?? throw new ArgumentNullException(nameof(chatRepository));
    }

    public override async Task OnConnectedAsync()
    {
        var publicId = GetUserPublicId(Context.User);

        if (publicId.HasValue)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, GetUserGroupName(publicId.Value)).ConfigureAwait(false);
        }

        await base.OnConnectedAsync().ConfigureAwait(false);
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var publicId = GetUserPublicId(Context.User);

        if (publicId.HasValue)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, GetUserGroupName(publicId.Value)).ConfigureAwait(false);
        }

        await base.OnDisconnectedAsync(exception).ConfigureAwait(false);
    }

    public async Task JoinConversation(Guid conversationPublicId, CancellationToken cancellationToken = default)
    {
        if (conversationPublicId == Guid.Empty)
        {
            throw new HubException("conversation_required");
        }

        var userPublicId = GetUserPublicId(Context.User);

        if (!userPublicId.HasValue)
        {
            throw new HubException("unauthorized");
        }

        var isMember = await _chatRepository.IsConversationMemberAsync(conversationPublicId, userPublicId.Value, cancellationToken).ConfigureAwait(false);

        if (!isMember)
        {
            throw new HubException("conversation_access_denied");
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, GetConversationGroupName(conversationPublicId), cancellationToken).ConfigureAwait(false);
    }

    public Task LeaveConversation(Guid conversationPublicId, CancellationToken cancellationToken = default)
    {
        if (conversationPublicId == Guid.Empty)
        {
            return Task.CompletedTask;
        }

        return Groups.RemoveFromGroupAsync(Context.ConnectionId, GetConversationGroupName(conversationPublicId), cancellationToken);
    }

    internal static string GetConversationGroupName(Guid conversationPublicId) => $"conversation:{conversationPublicId:N}";

    internal static string GetUserGroupName(Guid userPublicId) => $"user:{userPublicId:N}";

    private static Guid? GetUserPublicId(ClaimsPrincipal? principal)
    {
        if (principal is null)
        {
            return null;
        }

        var candidates = new[]
        {
            principal.FindFirstValue("uid"),
            principal.FindFirstValue("firebase_uid"),
            principal.FindFirstValue(ClaimTypes.NameIdentifier),
            principal.FindFirstValue(JwtRegisteredClaimNames.Sub)
        };

        foreach (var candidate in candidates)
        {
            if (!string.IsNullOrWhiteSpace(candidate) && Guid.TryParse(candidate, out var guid))
            {
                return guid;
            }
        }

        return null;
    }
}
