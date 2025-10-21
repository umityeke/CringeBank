using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Abstractions.Pipeline;
using CringeBank.Application.Abstractions.Queries;

namespace CringeBank.Application;

public sealed class Dispatcher : IDispatcher
{
    private readonly IServiceProvider _serviceProvider;

    public Dispatcher(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));
    }

    public Task<TResult> SendAsync<TCommand, TResult>(TCommand command, CancellationToken cancellationToken = default)
        where TCommand : ICommand<TResult>
    {
        ArgumentNullException.ThrowIfNull(command);

        var handler = (ICommandHandler<TCommand, TResult>?)_serviceProvider.GetService(typeof(ICommandHandler<TCommand, TResult>));

        if (handler is null)
        {
            throw new InvalidOperationException($"'{typeof(ICommandHandler<TCommand, TResult>)}' işleyicisi bulunamadı.");
        }

        var behaviors = (IEnumerable<ICommandPipelineBehavior<TCommand, TResult>>?)_serviceProvider.GetService(typeof(IEnumerable<ICommandPipelineBehavior<TCommand, TResult>>))
                         ?? Enumerable.Empty<ICommandPipelineBehavior<TCommand, TResult>>();

        var pipeline = BuildCommandPipeline(handler, behaviors);
        return pipeline(command, cancellationToken);
    }

    public Task<TResult> QueryAsync<TQuery, TResult>(TQuery query, CancellationToken cancellationToken = default)
        where TQuery : IQuery<TResult>
    {
        ArgumentNullException.ThrowIfNull(query);

        var handler = (IQueryHandler<TQuery, TResult>?)_serviceProvider.GetService(typeof(IQueryHandler<TQuery, TResult>));

        if (handler is null)
        {
            throw new InvalidOperationException($"'{typeof(IQueryHandler<TQuery, TResult>)}' işleyicisi bulunamadı.");
        }

        var behaviors = (IEnumerable<IQueryPipelineBehavior<TQuery, TResult>>?)_serviceProvider.GetService(typeof(IEnumerable<IQueryPipelineBehavior<TQuery, TResult>>))
                         ?? Enumerable.Empty<IQueryPipelineBehavior<TQuery, TResult>>();

        var pipeline = BuildQueryPipeline(handler, behaviors);
        return pipeline(query, cancellationToken);
    }

    private static CommandHandlerDelegate<TCommand, TResult> BuildCommandPipeline<TCommand, TResult>(
        ICommandHandler<TCommand, TResult> handler,
        IEnumerable<ICommandPipelineBehavior<TCommand, TResult>> behaviors)
        where TCommand : ICommand<TResult>
    {
        CommandHandlerDelegate<TCommand, TResult> next = (command, cancellationToken) => handler.HandleAsync(command, cancellationToken);

        foreach (var behavior in behaviors.Reverse())
        {
            var current = next;
            next = (command, cancellationToken) => behavior.HandleAsync(command, current, cancellationToken);
        }

        return next;
    }

    private static QueryHandlerDelegate<TQuery, TResult> BuildQueryPipeline<TQuery, TResult>(
        IQueryHandler<TQuery, TResult> handler,
        IEnumerable<IQueryPipelineBehavior<TQuery, TResult>> behaviors)
        where TQuery : IQuery<TResult>
    {
        QueryHandlerDelegate<TQuery, TResult> next = (query, cancellationToken) => handler.HandleAsync(query, cancellationToken);

        foreach (var behavior in behaviors.Reverse())
        {
            var current = next;
            next = (query, cancellationToken) => behavior.HandleAsync(query, current, cancellationToken);
        }

        return next;
    }
}
