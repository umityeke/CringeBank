using System;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Events;
using CringeBank.Application.Outbox;
using CringeBank.Domain.Events.Users;

namespace CringeBank.Application.Users.Events;

public sealed class UserSynchronizationCompletedDomainEventHandler : IDomainEventHandler<UserSynchronizationCompletedDomainEvent>
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly IOutboxEventWriter _outboxEventWriter;

    public UserSynchronizationCompletedDomainEventHandler(IOutboxEventWriter outboxEventWriter)
    {
        _outboxEventWriter = outboxEventWriter ?? throw new ArgumentNullException(nameof(outboxEventWriter));
    }

    public Task HandleAsync(UserSynchronizationCompletedDomainEvent domainEvent, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(domainEvent);

        var payload = JsonSerializer.Serialize(new
        {
            domainEvent.UserId,
            domainEvent.FirebaseUid,
            domainEvent.LastSyncedAtUtc,
            domainEvent.OccurredOnUtc
        }, JsonOptions);

        return _outboxEventWriter.EnqueueAsync(
            new OutboxEventCommand("users.sync.completed", payload),
            cancellationToken);
    }
}
