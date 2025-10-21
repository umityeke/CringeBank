using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Auth;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Auth.Enums;
using CringeBank.Domain.Chat.Entities;

namespace CringeBank.Application.Chats;

public sealed class MarkConversationReadCommandHandler : ICommandHandler<MarkConversationReadCommand, MarkConversationReadCommandResult>
{
    private readonly IAuthUserRepository _authUserRepository;
    private readonly IChatRepository _chatRepository;
    private readonly IChatEventPublisher _eventPublisher;

    public MarkConversationReadCommandHandler(
        IAuthUserRepository authUserRepository,
        IChatRepository chatRepository,
        IChatEventPublisher eventPublisher)
    {
        _authUserRepository = authUserRepository ?? throw new ArgumentNullException(nameof(authUserRepository));
        _chatRepository = chatRepository ?? throw new ArgumentNullException(nameof(chatRepository));
        _eventPublisher = eventPublisher ?? throw new ArgumentNullException(nameof(eventPublisher));
    }

    public async Task<MarkConversationReadCommandResult> HandleAsync(MarkConversationReadCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        var user = await _authUserRepository.GetByPublicIdAsync(command.UserPublicId, cancellationToken).ConfigureAwait(false);

        if (user is null)
        {
            return MarkConversationReadCommandResult.Failure("user_not_found");
        }

        if (!IsActive(user))
        {
            return MarkConversationReadCommandResult.Failure("user_not_active");
        }

        var conversation = await _chatRepository.GetConversationWithMembersAsync(command.ConversationPublicId, cancellationToken).ConfigureAwait(false);

        if (conversation is null)
        {
            return MarkConversationReadCommandResult.Failure("conversation_not_found");
        }

        var member = conversation.Members.FirstOrDefault(m => m.UserId == user.Id);

        if (member is null)
        {
            return MarkConversationReadCommandResult.Failure("user_not_member");
        }

        var message = await _chatRepository.GetMessageInConversationAsync(command.ConversationPublicId, command.MessageId, cancellationToken).ConfigureAwait(false);

        if (message is null)
        {
            return MarkConversationReadCommandResult.Failure("message_not_found");
        }

        member.UpdateLastRead(message.Id, DateTime.UtcNow);
        await _chatRepository.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var participantIds = CollectParticipantPublicIds(conversation);
        var result = new MarkConversationReadResult(
            conversation.PublicId,
            user.PublicId,
            message.Id,
            member.LastReadAt ?? DateTime.UtcNow,
            participantIds);

        await _eventPublisher.PublishConversationReadAsync(result, cancellationToken).ConfigureAwait(false);

        return MarkConversationReadCommandResult.SuccessResult(result);
    }

    private static bool IsActive(AuthUser user) => user.Status is AuthUserStatus.Active;

    private static Guid[] CollectParticipantPublicIds(Conversation conversation)
    {
        return conversation.Members
            .Select(member => member.User?.PublicId ?? Guid.Empty)
            .Where(id => id != Guid.Empty)
            .Distinct()
            .ToArray();
    }
}
