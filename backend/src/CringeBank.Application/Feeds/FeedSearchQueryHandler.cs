using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Queries;

namespace CringeBank.Application.Feeds;

public sealed class FeedSearchQueryHandler : IQueryHandler<FeedSearchQuery, FeedCursorPage<FeedItemResult>>
{
    private readonly IFeedReadRepository _repository;

    public FeedSearchQueryHandler(IFeedReadRepository repository)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
    }

    public Task<FeedCursorPage<FeedItemResult>> HandleAsync(FeedSearchQuery query, CancellationToken cancellationToken)
    {
        if (query is null)
        {
            throw new ArgumentNullException(nameof(query));
        }

        return _repository.SearchAsync(query, cancellationToken);
    }
}
