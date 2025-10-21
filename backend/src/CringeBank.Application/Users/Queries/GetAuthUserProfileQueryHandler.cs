using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Queries;

namespace CringeBank.Application.Users.Queries;

public sealed class GetAuthUserProfileQueryHandler : IQueryHandler<GetAuthUserProfileQuery, UserProfileResult?>
{
    private readonly IUserReadRepository _repository;

    public GetAuthUserProfileQueryHandler(IUserReadRepository repository)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
    }

    public Task<UserProfileResult?> HandleAsync(GetAuthUserProfileQuery query, CancellationToken cancellationToken)
    {
        if (query is null)
        {
            throw new ArgumentNullException(nameof(query));
        }

        return _repository.GetProfileByPublicIdAsync(query.PublicId, cancellationToken);
    }
}
