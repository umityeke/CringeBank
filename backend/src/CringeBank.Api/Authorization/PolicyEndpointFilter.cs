using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Threading.Tasks;
using CringeBank.Application.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Logging;
using Serilog.Context;

namespace CringeBank.Api.Authorization;

public sealed class PolicyEndpointFilter : IEndpointFilter
{
    private static readonly Action<ILogger, string, string, Guid, Exception?> LogPolicyDenied = LoggerMessage.Define<string, string, Guid>(
        LogLevel.Warning,
        new EventId(5200, nameof(LogPolicyDenied)),
        "Kullanıcı {UserId} için {Resource}.{Action} yetkisi reddedildi.");

    private static readonly Action<ILogger, string, string, Exception?> LogMissingUserClaim = LoggerMessage.Define<string, string>(
        LogLevel.Warning,
        new EventId(5201, nameof(LogMissingUserClaim)),
        "Policy kontrolü için gerekli kullanıcı kimliği bulunamadı: {Resource}.{Action}");

    private readonly IPolicyEvaluator _policyEvaluator;
    private readonly ILogger<PolicyEndpointFilter> _logger;

    public PolicyEndpointFilter(IPolicyEvaluator policyEvaluator, ILogger<PolicyEndpointFilter> logger)
    {
        _policyEvaluator = policyEvaluator ?? throw new ArgumentNullException(nameof(policyEvaluator));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(next);

        var endpoint = context.HttpContext.GetEndpoint();
        if (endpoint is null)
        {
            return await next(context).ConfigureAwait(false);
        }

        if (endpoint.Metadata.GetMetadata<IAllowAnonymous>() is not null)
        {
            return await next(context).ConfigureAwait(false);
        }

        var policyMetadata = endpoint.Metadata.GetMetadata<RbacPolicyAttribute>();
        if (policyMetadata is null)
        {
            return await next(context).ConfigureAwait(false);
        }

        if (context.HttpContext.User?.Identity?.IsAuthenticated != true)
        {
            return Results.Unauthorized();
        }

        var uidClaim = context.HttpContext.User.FindFirst("uid")
            ?? context.HttpContext.User.FindFirst(ClaimTypes.NameIdentifier)
            ?? context.HttpContext.User.FindFirst(JwtRegisteredClaimNames.Sub);
        if (uidClaim is null || !Guid.TryParse(uidClaim.Value, out var userPublicId))
        {
                using (LogContext.PushProperty("SecurityEvent", true))
                {
                    LogMissingUserClaim(_logger, policyMetadata.Resource, policyMetadata.Action, null);
                }
            return Results.StatusCode(StatusCodes.Status403Forbidden);
        }

        var allowed = await _policyEvaluator.IsAllowedAsync(
            userPublicId,
            policyMetadata.Resource,
            policyMetadata.Action,
            scopeContext: null,
            cancellationToken: context.HttpContext.RequestAborted).ConfigureAwait(false);

        if (!allowed)
        {
            using (LogContext.PushProperty("SecurityEvent", true))
            {
                LogPolicyDenied(_logger, policyMetadata.Resource, policyMetadata.Action, userPublicId, null);
            }
            return Results.StatusCode(StatusCodes.Status403Forbidden);
        }

        return await next(context).ConfigureAwait(false);
    }
}
