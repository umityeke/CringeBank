using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Authorization;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CringeBank.Infrastructure.Authorization;

public sealed class PolicyEvaluator : IPolicyEvaluator
{
    private static readonly Action<ILogger, string, string, Guid, string, Exception?> LogPolicyDenied = LoggerMessage.Define<string, string, Guid, string>(
        LogLevel.Information,
        new EventId(4200, nameof(LogPolicyDenied)),
        "Policy reddedildi: {Resource}.{Action} (Kullanıcı: {UserId}, Roller: {Roles})");

    private static readonly Action<ILogger, string, string, Exception?> LogPolicyMissing = LoggerMessage.Define<string, string>(
        LogLevel.Warning,
        new EventId(4201, nameof(LogPolicyMissing)),
        "Policy tanımı bulunamadı: {Resource}.{Action}");

    private readonly CringeBankDbContext _dbContext;
    private readonly IMemoryCache _cache;
    private readonly ILogger<PolicyEvaluator> _logger;
    private readonly IOptionsMonitor<RbacOptions> _optionsMonitor;

    private Dictionary<string, PolicyDefinition> _policyLookup = new(StringComparer.OrdinalIgnoreCase);
    private HashSet<string> _twoManActions = new(StringComparer.OrdinalIgnoreCase);
    private TimeSpan _rolesCacheDuration;

    public PolicyEvaluator(
        CringeBankDbContext dbContext,
        IMemoryCache cache,
        IOptionsMonitor<RbacOptions> optionsMonitor,
        ILogger<PolicyEvaluator> logger)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
        _cache = cache ?? throw new ArgumentNullException(nameof(cache));
        _optionsMonitor = optionsMonitor ?? throw new ArgumentNullException(nameof(optionsMonitor));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));

        UpdateState(optionsMonitor.CurrentValue);
        _optionsMonitor.OnChange(UpdateState);
    }

    public async Task<bool> IsAllowedAsync(
        Guid userPublicId,
        string resource,
        string action,
        IReadOnlyDictionary<string, string>? scopeContext = null,
        CancellationToken cancellationToken = default)
    {
        if (userPublicId == Guid.Empty)
        {
            throw new ArgumentException("User public id is required.", nameof(userPublicId));
        }

        var policy = TryGetPolicy(resource, action);
        if (policy is null)
        {
            LogPolicyMissing(_logger, resource, action, null);
            return false;
        }

        var roles = await GetUserRolesAsync(userPublicId, cancellationToken).ConfigureAwait(false);
        var allowed = roles.Any(role => policy.Roles.Contains(role, StringComparer.OrdinalIgnoreCase));

        if (!allowed)
        {
            LogPolicyDenied(_logger, resource, action, userPublicId, string.Join(", ", roles), null);
        }

        return allowed;
    }

    public async Task EnsureAllowedAsync(
        Guid userPublicId,
        string resource,
        string action,
        IReadOnlyDictionary<string, string>? scopeContext = null,
        CancellationToken cancellationToken = default)
    {
        var allowed = await IsAllowedAsync(userPublicId, resource, action, scopeContext, cancellationToken).ConfigureAwait(false);
        if (!allowed)
        {
            throw new PolicyDeniedException(resource, action);
        }
    }

    public bool RequiresTwoManApproval(string resource, string action)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(resource);
        ArgumentException.ThrowIfNullOrWhiteSpace(action);

        var key = ComposeKey(resource, action);
        return _twoManActions.Contains(key);
    }

    private PolicyDefinition? TryGetPolicy(string resource, string action)
    {
        if (string.IsNullOrWhiteSpace(resource) || string.IsNullOrWhiteSpace(action))
        {
            return null;
        }

        var key = ComposeKey(resource, action);
        return _policyLookup.TryGetValue(key, out var policy) ? policy : null;
    }

    private static string ComposeKey(string resource, string action)
    {
        return string.Create(resource.Length + action.Length + 1, (resource, action), static (span, state) =>
        {
            var (res, act) = state;
            res.AsSpan().CopyTo(span);
            span[res.Length] = '.';
            act.AsSpan().CopyTo(span[(res.Length + 1)..]);
            for (var i = 0; i < span.Length; i++)
            {
                span[i] = char.ToLowerInvariant(span[i]);
            }
        });
    }

    private async Task<IReadOnlyList<string>> GetUserRolesAsync(Guid userPublicId, CancellationToken cancellationToken)
    {
        var cacheKey = $"rbac:roles:{userPublicId:N}";

        if (_cache.TryGetValue(cacheKey, out IReadOnlyList<string>? cachedRoles) && cachedRoles is not null)
        {
            return cachedRoles;
        }

        var roles = await _dbContext.AuthUserRoles
            .AsNoTracking()
            .Where(ur => ur.User.PublicId == userPublicId)
            .Select(ur => ur.Role.Name)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        if (roles.Count == 0)
        {
            roles.Add("user");
        }

        var result = roles
            .Select(role => role.ToLowerInvariant())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var cacheEntryOptions = new MemoryCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = _rolesCacheDuration
        };

        _cache.Set(cacheKey, result, cacheEntryOptions);
        return result;
    }

    private void UpdateState(RbacOptions options)
    {
        var policies = new Dictionary<string, PolicyDefinition>(StringComparer.OrdinalIgnoreCase);

        if (options.Policies is not null)
        {
            foreach (var policy in options.Policies)
            {
                if (string.IsNullOrWhiteSpace(policy.Resource) || string.IsNullOrWhiteSpace(policy.Action))
                {
                    continue;
                }

                var key = ComposeKey(policy.Resource, policy.Action);
                policies[key] = policy;
            }
        }

        Volatile.Write(ref _policyLookup, policies);
        Volatile.Write(ref _twoManActions, new HashSet<string>(options.TwoManApprovalActions ?? Array.Empty<string>(), StringComparer.OrdinalIgnoreCase));
        _rolesCacheDuration = TimeSpan.FromSeconds(Math.Max(5, options.RolesCacheSeconds));
    }
}
