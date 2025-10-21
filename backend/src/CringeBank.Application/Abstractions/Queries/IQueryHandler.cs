using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Abstractions.Queries;

public interface IQueryHandler<TQuery, TResult>
    where TQuery : IQuery<TResult>
{
    Task<TResult> HandleAsync(TQuery query, CancellationToken cancellationToken);
}
