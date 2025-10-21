using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Abstractions.Pipeline;
using FluentValidation;
using FluentValidation.Results;

namespace CringeBank.Application.Pipeline;

public sealed class ValidationCommandPipelineBehavior<TCommand, TResult> : ICommandPipelineBehavior<TCommand, TResult>
    where TCommand : ICommand<TResult>
{
    private readonly IEnumerable<IValidator<TCommand>> _validators;

    public ValidationCommandPipelineBehavior(IEnumerable<IValidator<TCommand>> validators)
    {
        _validators = validators ?? Enumerable.Empty<IValidator<TCommand>>();
    }

    public async Task<TResult> HandleAsync(TCommand command, CommandHandlerDelegate<TCommand, TResult> next, CancellationToken cancellationToken)
    {
        if (next is null)
        {
            throw new ArgumentNullException(nameof(next));
        }

        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        var validators = _validators as IValidator<TCommand>[] ?? _validators.ToArray();

        if (validators.Length > 0)
        {
            var context = new ValidationContext<TCommand>(command);
            var failures = new List<ValidationFailure>();

            foreach (var validator in validators)
            {
                var result = await validator.ValidateAsync(context, cancellationToken).ConfigureAwait(false);
                if (!result.IsValid)
                {
                    failures.AddRange(result.Errors);
                }
            }

            if (failures.Count > 0)
            {
                throw new ValidationException("Komut doğrulaması başarısız.", failures);
            }
        }

        return await next(command, cancellationToken).ConfigureAwait(false);
    }
}
