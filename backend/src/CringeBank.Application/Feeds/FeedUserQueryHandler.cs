using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Queries;

namespace CringeBank.Application.Feeds;

public sealed class FeedUserQueryHandler : IQueryHandler<FeedUserQuery, FeedCursorPage<FeedItemResult>>
{
    private readonly IFeedReadRepository _repository;

    public FeedUserQueryHandler(IFeedReadRepository repository)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
    }

    public Task<FeedCursorPage<FeedItemResult>> HandleAsync(FeedUserQuery query, CancellationToken cancellationToken)
    {
        if (query is null)
        {
            throw new ArgumentNullException(nameof(query));
        }

        return _repository.GetUserFeedAsync(query, cancellationToken);
    }
}
