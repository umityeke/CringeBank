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
using CringeBank.Domain.Chat.Enums;
using CringeBank.Domain.ValueObjects;
using Microsoft.Extensions.Logging;

namespace CringeBank.Application.Chats;

public sealed class CreateConversationCommandHandler : ICommandHandler<CreateConversationCommand, CreateConversationResult>
{
    private readonly IAuthUserRepository _authUserRepository;
    private readonly IChatRepository _chatRepository;
    private readonly IChatEventPublisher _eventPublisher;

    public CreateConversationCommandHandler(
        IAuthUserRepository authUserRepository,
        IChatRepository chatRepository,
        IChatEventPublisher eventPublisher)
    {
        _authUserRepository = authUserRepository ?? throw new ArgumentNullException(nameof(authUserRepository));
        _chatRepository = chatRepository ?? throw new ArgumentNullException(nameof(chatRepository));
        _eventPublisher = eventPublisher ?? throw new ArgumentNullException(nameof(eventPublisher));
    }

    public async Task<CreateConversationResult> HandleAsync(CreateConversationCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        var initiator = await _authUserRepository.GetByPublicIdAsync(command.InitiatorPublicId, cancellationToken).ConfigureAwait(false);

        if (initiator is null)
        {
            return CreateConversationResult.Failure("initiator_not_found");
        }

        if (!IsUserActive(initiator))
        {
            return CreateConversationResult.Failure("initiator_not_active");
        }

        var participantIds = (command.ParticipantPublicIds ?? Array.Empty<Guid>())
            .Distinct()
            .Where(id => id != command.InitiatorPublicId)
            .ToArray();
        var participantEntities = await _authUserRepository.GetByPublicIdsAsync(participantIds, cancellationToken).ConfigureAwait(false);

        if (participantEntities.Count != participantIds.Length)
        {
            return CreateConversationResult.Failure("participant_not_found");
        }

        if (participantEntities.Any(user => !IsUserActive(user)))
        {
            return CreateConversationResult.Failure("participant_not_active");
        }

        var title = ConversationTitle.Create(command.Title);
        var conversation = Conversation.Create(initiator.Id, command.IsGroup, title);
        conversation.AddMember(initiator, ConversationMemberRole.Owner);

        foreach (var participant in participantEntities)
        {
            conversation.AddMember(participant, ConversationMemberRole.Participant);
        }

        _chatRepository.AddConversation(conversation);
        await _chatRepository.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var conversationResult = MapConversationResult(conversation, initiator, participantEntities);
        await _eventPublisher.PublishConversationCreatedAsync(conversationResult, cancellationToken).ConfigureAwait(false);

        return CreateConversationResult.SuccessResult(conversationResult);
    }

    private static bool IsUserActive(AuthUser user)
    {
        return user.Status is AuthUserStatus.Active;
    }

    private static ConversationResult MapConversationResult(Conversation conversation, AuthUser initiator, IReadOnlyCollection<AuthUser> participants)
    {
        var users = new Dictionary<long, AuthUser>
        {
            [initiator.Id] = initiator
        };

        foreach (var participant in participants)
        {
            users[participant.Id] = participant;
        }

        var members = conversation.Members
            .Select(member =>
            {
                users.TryGetValue(member.UserId, out var authUser);
                var userPublicId = authUser?.PublicId ?? Guid.Empty;
                return new ConversationMemberResult(
                    userPublicId,
                    member.Role,
                    member.JoinedAt,
                    member.LastReadMessageId,
                    member.LastReadAt);
            })
            .ToArray();

        return new ConversationResult(
            conversation.PublicId,
            conversation.IsGroup,
            conversation.Title,
            conversation.CreatedAt,
            conversation.UpdatedAt,
            members);
    }
}
