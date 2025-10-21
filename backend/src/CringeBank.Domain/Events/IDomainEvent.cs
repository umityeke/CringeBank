using System;

namespace CringeBank.Domain.Events;

public interface IDomainEvent
{
    DateTimeOffset OccurredOnUtc { get; }
}
