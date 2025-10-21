using System;

namespace CringeBank.Domain.Events;

public abstract record DomainEvent : IDomainEvent
{
    protected DomainEvent()
    {
        OccurredOnUtc = DateTimeOffset.UtcNow;
    }

    protected DomainEvent(DateTimeOffset occurredOnUtc)
    {
        OccurredOnUtc = occurredOnUtc;
    }

    public DateTimeOffset OccurredOnUtc { get; }
}
