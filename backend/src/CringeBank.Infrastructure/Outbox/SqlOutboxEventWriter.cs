using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Outbox;
using CringeBank.Domain.Outbox.Entities;
using CringeBank.Infrastructure.Persistence;

namespace CringeBank.Infrastructure.Outbox;

public sealed class SqlOutboxEventWriter : IOutboxEventWriter
{
    private readonly CringeBankDbContext _dbContext;

    public SqlOutboxEventWriter(CringeBankDbContext dbContext)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
    }

    public async Task<long> EnqueueAsync(OutboxEventCommand command, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(command);

        var outboxEvent = new OutboxEvent(command.Topic, command.Payload);

        await _dbContext.OutboxEvents.AddAsync(outboxEvent, cancellationToken).ConfigureAwait(false);
        await _dbContext.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return outboxEvent.Id;
    }
}
