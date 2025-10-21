using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Abstractions.Pipeline;

public delegate Task<TResult> CommandHandlerDelegate<TCommand, TResult>(TCommand command, CancellationToken cancellationToken);
