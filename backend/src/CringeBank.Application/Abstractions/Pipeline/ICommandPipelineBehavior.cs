using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Abstractions.Pipeline;

public interface ICommandPipelineBehavior<TCommand, TResult>
{
    Task<TResult> HandleAsync(TCommand command, CommandHandlerDelegate<TCommand, TResult> next, CancellationToken cancellationToken);
}
