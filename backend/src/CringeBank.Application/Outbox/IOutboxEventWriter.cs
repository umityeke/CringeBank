using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Outbox;

public interface IOutboxEventWriter
{
    Task<long> EnqueueAsync(OutboxEventCommand command, CancellationToken cancellationToken = default);
}

public sealed record OutboxEventCommand(string Topic, string Payload);
