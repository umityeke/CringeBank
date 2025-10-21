using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Abstractions.Pipeline;

public delegate Task<TResult> QueryHandlerDelegate<TQuery, TResult>(TQuery query, CancellationToken cancellationToken);
