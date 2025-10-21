using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Authorization;

public interface IPolicyEvaluator
{
    Task<bool> IsAllowedAsync(
        Guid userPublicId,
        string resource,
        string action,
        IReadOnlyDictionary<string, string>? scopeContext = null,
        CancellationToken cancellationToken = default);

    Task EnsureAllowedAsync(
        Guid userPublicId,
        string resource,
        string action,
        IReadOnlyDictionary<string, string>? scopeContext = null,
        CancellationToken cancellationToken = default);

    bool RequiresTwoManApproval(string resource, string action);
}
