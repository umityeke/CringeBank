using System.Threading;
using System.Threading.Tasks;
using CringeBank.Domain.Events;

namespace CringeBank.Application.Abstractions.Events;

public interface IDomainEventHandler<in TEvent>
    where TEvent : IDomainEvent
{
    Task HandleAsync(TEvent domainEvent, CancellationToken cancellationToken = default);
}
