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
using CringeBank.Domain.ValueObjects;

namespace CringeBank.Application.Chats;

public sealed class SendMessageCommandHandler : ICommandHandler<SendMessageCommand, SendMessageResult>
{
    private readonly IAuthUserRepository _authUserRepository;
    private readonly IChatRepository _chatRepository;
    private readonly IChatEventPublisher _eventPublisher;

    public SendMessageCommandHandler(
        IAuthUserRepository authUserRepository,
        IChatRepository chatRepository,
        IChatEventPublisher eventPublisher)
    {
        _authUserRepository = authUserRepository ?? throw new ArgumentNullException(nameof(authUserRepository));
        _chatRepository = chatRepository ?? throw new ArgumentNullException(nameof(chatRepository));
        _eventPublisher = eventPublisher ?? throw new ArgumentNullException(nameof(eventPublisher));
    }

    public async Task<SendMessageResult> HandleAsync(SendMessageCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        var sender = await _authUserRepository.GetByPublicIdAsync(command.SenderPublicId, cancellationToken).ConfigureAwait(false);

        if (sender is null)
        {
            return SendMessageResult.Failure("sender_not_found");
        }

        if (!IsActive(sender))
        {
            return SendMessageResult.Failure("sender_not_active");
        }

        var conversation = await _chatRepository.GetConversationWithMembersAsync(command.ConversationPublicId, cancellationToken).ConfigureAwait(false);

        if (conversation is null)
        {
            return SendMessageResult.Failure("conversation_not_found");
        }

        if (!conversation.Members.Any(member => member.UserId == sender.Id))
        {
            return SendMessageResult.Failure("sender_not_member");
        }

        MessageBody body;
        try
        {
            body = MessageBody.Create(command.Body);
        }
        catch (ArgumentException)
        {
            return SendMessageResult.Failure("invalid_body");
        }

        var message = conversation.AddMessage(sender, body);
        await _chatRepository.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var senderMember = conversation.Members.First(member => member.UserId == sender.Id);
        senderMember.UpdateLastRead(message.Id, message.CreatedAt);
        await _chatRepository.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var participantIds = CollectParticipantPublicIds(conversation);
        var messageResult = new MessageResult(
            message.Id,
            conversation.PublicId,
            sender.PublicId,
            message.Body,
            message.DeletedForAll,
            message.CreatedAt,
            message.EditedAt,
            participantIds);

        await _eventPublisher.PublishMessageSentAsync(messageResult, cancellationToken).ConfigureAwait(false);

        return SendMessageResult.SuccessResult(messageResult);
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
