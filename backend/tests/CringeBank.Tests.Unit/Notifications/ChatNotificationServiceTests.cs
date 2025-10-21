using System;
using System.Linq;
using System.Threading.Tasks;
using CringeBank.Application.Chats;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Notify.Enums;
using CringeBank.Domain.ValueObjects;
using CringeBank.Infrastructure.Notifications;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace CringeBank.Tests.Unit.Notifications;

public sealed class ChatNotificationServiceTests
{
    [Fact]
    public async Task queue_async_creates_notifications_and_outbox_entries_for_each_recipient()
    {
        var options = new DbContextOptionsBuilder<CringeBankDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;

        await using var dbContext = new CringeBankDbContext(options);

        var sender = AuthUser.Create(
            EmailAddress.Create("sender@example.com"),
            Username.Create("sender"));
        dbContext.AuthUsers.Add(sender);
        await dbContext.SaveChangesAsync();

        sender.UpdateProfile(
            DisplayName.Create("Sender"),
            ProfileBio.Create("Merhaba"),
            WebsiteUrl.Create("https://sender.example.com"),
            "https://cdn.example.com/sender.png",
            null,
            null);
        await dbContext.SaveChangesAsync();

        var recipient = AuthUser.Create(
            EmailAddress.Create("recipient@example.com"),
            Username.Create("recipient"));
        dbContext.AuthUsers.Add(recipient);
        await dbContext.SaveChangesAsync();

        recipient.UpdateProfile(
            DisplayName.Create("Recipient"),
            ProfileBio.Create("Selam"),
            WebsiteUrl.Create("https://recipient.example.com"),
            "https://cdn.example.com/recipient.png",
            null,
            null);
        await dbContext.SaveChangesAsync();

        var service = new ChatNotificationService(dbContext, NullLogger<ChatNotificationService>.Instance);

        var message = new MessageResult(
            42,
            Guid.NewGuid(),
            sender.PublicId,
            "Selam!",
            false,
            DateTime.UtcNow,
            null,
            new[] { sender.PublicId, recipient.PublicId });

        await service.QueueAsync(message);

        var notifications = await dbContext.Notifications
            .Include(notification => notification.OutboxMessages)
            .ToListAsync();

        Assert.Single(notifications);

        var notification = notifications.Single();
        Assert.Equal(recipient.Id, notification.RecipientUserId);
        Assert.Equal(sender.Id, notification.SenderUserId);
        Assert.False(notification.IsRead);
        Assert.Equal("Selam!", notification.Body);

        var outboxMessages = notification.OutboxMessages.ToList();
        Assert.Equal(2, outboxMessages.Count);
    Assert.Contains(outboxMessages, entry => entry.Channel == NotificationDeliveryChannel.Push);
    Assert.Contains(outboxMessages, entry => entry.Channel == NotificationDeliveryChannel.Email);
    }
}
