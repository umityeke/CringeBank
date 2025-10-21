using System.Threading;
using System.Threading.Tasks;
using CringeBank.Domain.Events;

namespace CringeBank.Application.Abstractions.Events;

public interface IDomainEventDispatcher
{
    Task PublishAsync(IDomainEvent domainEvent, CancellationToken cancellationToken = default);
}
