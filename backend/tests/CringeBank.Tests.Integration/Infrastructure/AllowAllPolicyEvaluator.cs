namespace CringeBank.Tests.Integration.Infrastructure;

using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Authorization;

public sealed class AllowAllPolicyEvaluator : IPolicyEvaluator
{
    public Task<bool> IsAllowedAsync(Guid userPublicId, string resource, string action, IReadOnlyDictionary<string, string>? scopeContext = null, CancellationToken cancellationToken = default)
    {
        return Task.FromResult(true);
    }

    public Task EnsureAllowedAsync(Guid userPublicId, string resource, string action, IReadOnlyDictionary<string, string>? scopeContext = null, CancellationToken cancellationToken = default)
    {
        return Task.CompletedTask;
    }

    public bool RequiresTwoManApproval(string resource, string action)
    {
        return false;
    }
}
