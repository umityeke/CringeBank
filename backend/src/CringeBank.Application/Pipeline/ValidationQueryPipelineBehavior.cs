using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Pipeline;
using CringeBank.Application.Abstractions.Queries;
using FluentValidation;
using FluentValidation.Results;

namespace CringeBank.Application.Pipeline;

public sealed class ValidationQueryPipelineBehavior<TQuery, TResult> : IQueryPipelineBehavior<TQuery, TResult>
    where TQuery : IQuery<TResult>
{
    private readonly IEnumerable<IValidator<TQuery>> _validators;

    public ValidationQueryPipelineBehavior(IEnumerable<IValidator<TQuery>> validators)
    {
        _validators = validators ?? Enumerable.Empty<IValidator<TQuery>>();
    }

    public async Task<TResult> HandleAsync(TQuery query, QueryHandlerDelegate<TQuery, TResult> next, CancellationToken cancellationToken)
    {
        if (next is null)
        {
            throw new ArgumentNullException(nameof(next));
        }

        if (query is null)
        {
            throw new ArgumentNullException(nameof(query));
        }

        var validators = _validators as IValidator<TQuery>[] ?? _validators.ToArray();

        if (validators.Length > 0)
        {
            var context = new ValidationContext<TQuery>(query);
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
                throw new ValidationException("Sorgu doğrulaması başarısız.", failures);
            }
        }

        return await next(query, cancellationToken).ConfigureAwait(false);
    }
}
