using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Chats;
using CringeBank.Application.Notifications;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Notify.Entities;
using CringeBank.Domain.Notify.Enums;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CringeBank.Infrastructure.Notifications;

public sealed class ChatNotificationService : IChatNotificationService
{
    private const string PushTopic = "notify.push.chat_message";
    private const string EmailTopic = "notify.email.chat_message";

    private static readonly Action<ILogger, Guid, long, Exception?> SenderMissingLog =
        LoggerMessage.Define<Guid, long>(LogLevel.Warning, new EventId(2100, nameof(SenderMissingLog)), "Sender with publicId {SenderPublicId} not found for message {MessageId}");

    private static readonly Action<ILogger, long, Exception?> RecipientsMissingLog =
        LoggerMessage.Define<long>(LogLevel.Warning, new EventId(2101, nameof(RecipientsMissingLog)), "Recipients not found for message {MessageId}");

    private readonly CringeBankDbContext _dbContext;
    private readonly ILogger<ChatNotificationService> _logger;

    public ChatNotificationService(CringeBankDbContext dbContext, ILogger<ChatNotificationService> logger)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async Task QueueAsync(MessageResult message, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(message);

        var sender = await _dbContext.AuthUsers
            .Include(user => user.Profile)
            .SingleOrDefaultAsync(user => user.PublicId == message.SenderPublicId, cancellationToken)
            .ConfigureAwait(false);

        if (sender is null)
        {
            SenderMissingLog(_logger, message.SenderPublicId, message.Id, null);
            return;
        }

        var recipientPublicIds = message.ParticipantPublicIds
            .Where(id => id != message.SenderPublicId)
            .Distinct()
            .ToArray();

        if (recipientPublicIds.Length == 0)
        {
            return;
        }

        var recipients = await _dbContext.AuthUsers
            .Include(user => user.Profile)
            .Where(user => recipientPublicIds.Contains(user.PublicId))
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        if (recipients.Count == 0)
        {
            RecipientsMissingLog(_logger, message.Id, null);
            return;
        }

        foreach (var recipient in recipients)
        {
            var notification = Notification.Create(
                recipient.Id,
                NotificationType.DirectMessage,
                BuildTitle(sender),
                message.Body,
                BuildActionUrl(message.ConversationPublicId),
                sender.Profile?.AvatarUrl,
                BuildNotificationPayload(message, sender, recipient),
                sender.Id);

            _dbContext.Notifications.Add(notification);

            var pushPayload = BuildPushPayload(notification, message, sender, recipient);
            var pushOutbox = NotificationOutboxMessage.Create(notification, NotificationDeliveryChannel.Push, PushTopic, pushPayload);
            _dbContext.NotificationOutboxMessages.Add(pushOutbox);

            var emailPayload = BuildEmailPayload(notification, message, sender, recipient);
            var emailOutbox = NotificationOutboxMessage.Create(notification, NotificationDeliveryChannel.Email, EmailTopic, emailPayload);
            _dbContext.NotificationOutboxMessages.Add(emailOutbox);
        }

        await _dbContext.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    private static string BuildTitle(AuthUser sender)
    {
        var displayName = sender.Profile?.DisplayName;
        if (string.IsNullOrWhiteSpace(displayName))
        {
            displayName = sender.Username;
        }

        return string.IsNullOrWhiteSpace(displayName)
            ? "Yeni mesajınız var"
            : $"{displayName} size yeni bir mesaj gönderdi";
    }

    private static string BuildActionUrl(Guid conversationPublicId)
    {
        return $"cringebank://chat/{conversationPublicId:D}";
    }

    private static object BuildNotificationPayload(MessageResult message, AuthUser sender, AuthUser recipient)
    {
        return new
        {
            notificationType = NotificationType.DirectMessage.ToString(),
            conversationId = message.ConversationPublicId,
            messageId = message.Id,
            senderPublicId = sender.PublicId,
            recipientPublicId = recipient.PublicId,
            body = message.Body,
            createdAtUtc = message.CreatedAt
        };
    }

    private static object BuildPushPayload(Notification notification, MessageResult message, AuthUser sender, AuthUser recipient)
    {
        return new
        {
            notificationId = notification.PublicId,
            recipientUserId = recipient.PublicId,
            sender = new
            {
                sender.PublicId,
                displayName = sender.Profile?.DisplayName ?? sender.Username,
                avatarUrl = sender.Profile?.AvatarUrl
            },
            message = new
            {
                message.Id,
                message.ConversationPublicId,
                message.Body,
                message.CreatedAt
            },
            actionUrl = notification.ActionUrl
        };
    }

    private static object BuildEmailPayload(Notification notification, MessageResult message, AuthUser sender, AuthUser recipient)
    {
        return new
        {
            notificationId = notification.PublicId,
            recipientEmail = recipient.Email,
            subject = notification.Title,
            preview = notification.Body,
            template = "chat-new-message",
            model = new
            {
                recipientName = recipient.Profile?.DisplayName ?? recipient.Username,
                senderName = sender.Profile?.DisplayName ?? sender.Username,
                senderAvatar = sender.Profile?.AvatarUrl,
                messageBody = notification.Body,
                conversationLink = notification.ActionUrl,
                sentAt = message.CreatedAt
            }
        };
    }
}
