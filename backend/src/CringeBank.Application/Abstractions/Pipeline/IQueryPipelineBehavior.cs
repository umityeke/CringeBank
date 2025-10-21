using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Abstractions.Pipeline;

public interface IQueryPipelineBehavior<TQuery, TResult>
{
    Task<TResult> HandleAsync(TQuery query, QueryHandlerDelegate<TQuery, TResult> next, CancellationToken cancellationToken);
}
