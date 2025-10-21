using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Events;
using CringeBank.Domain.Events;
using Microsoft.Extensions.DependencyInjection;

namespace CringeBank.Application.Events;

public sealed class DomainEventDispatcher : IDomainEventDispatcher
{
    private readonly IServiceScopeFactory _serviceScopeFactory;

    public DomainEventDispatcher(IServiceScopeFactory serviceScopeFactory)
    {
        _serviceScopeFactory = serviceScopeFactory ?? throw new ArgumentNullException(nameof(serviceScopeFactory));
    }

    public async Task PublishAsync(IDomainEvent domainEvent, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(domainEvent);

        using var scope = _serviceScopeFactory.CreateScope();

        var handlerEnumerableType = typeof(IEnumerable<>).MakeGenericType(typeof(IDomainEventHandler<>).MakeGenericType(domainEvent.GetType()));
        var handlers = scope.ServiceProvider.GetService(handlerEnumerableType) as IEnumerable<object> ?? Array.Empty<object>();

        foreach (var handler in handlers)
        {
            var handleAsyncMethod = handler.GetType().GetMethod(
                nameof(IDomainEventHandler<IDomainEvent>.HandleAsync),
                new[] { domainEvent.GetType(), typeof(CancellationToken) });

            if (handleAsyncMethod is null)
            {
                continue;
            }

            var result = handleAsyncMethod.Invoke(handler, new object[] { domainEvent, cancellationToken }) as Task;
            if (result is not null)
            {
                await result.ConfigureAwait(false);
            }
        }
    }
}
