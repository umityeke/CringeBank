using System;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Events;
using CringeBank.Application.Outbox;
using CringeBank.Domain.Events.Users;
using CringeBank.Domain.Enums;

namespace CringeBank.Application.Users.Events;

public sealed class UserStatusChangedDomainEventHandler : IDomainEventHandler<UserStatusChangedDomainEvent>
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly IOutboxEventWriter _outboxEventWriter;

    public UserStatusChangedDomainEventHandler(IOutboxEventWriter outboxEventWriter)
    {
        _outboxEventWriter = outboxEventWriter ?? throw new ArgumentNullException(nameof(outboxEventWriter));
    }

    public Task HandleAsync(UserStatusChangedDomainEvent domainEvent, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(domainEvent);

        var payload = JsonSerializer.Serialize(new
        {
            domainEvent.UserId,
            domainEvent.FirebaseUid,
            PreviousStatus = domainEvent.PreviousStatus.ToString(),
            CurrentStatus = domainEvent.CurrentStatus.ToString(),
            domainEvent.OccurredOnUtc
        }, JsonOptions);

        return _outboxEventWriter.EnqueueAsync(
            new OutboxEventCommand("users.status.changed", payload),
            cancellationToken);
    }
}
