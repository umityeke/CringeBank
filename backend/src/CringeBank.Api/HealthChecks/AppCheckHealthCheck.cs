using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Api.Authentication;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CringeBank.Api.HealthChecks;

public sealed class AppCheckHealthCheck : IHealthCheck
{
    private static readonly string[] RequiredScopes =
    {
        "https://www.googleapis.com/auth/firebase",
        "https://www.googleapis.com/auth/cloud-platform"
    };

    private static readonly Action<ILogger, string, Exception?> LogAppCheckFailure = LoggerMessage.Define<string>(
        LogLevel.Error,
        new EventId(5502, nameof(LogAppCheckFailure)),
        "Firebase App Check health check failed: {Reason}.");

    private readonly AppCheckOptions _options;
    private readonly ILogger<AppCheckHealthCheck> _logger;

    public AppCheckHealthCheck(IOptions<AppCheckOptions> options, ILogger<AppCheckHealthCheck> logger)
    {
        _options = options?.Value ?? throw new ArgumentNullException(nameof(options));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(context);

        if (!_options.Enabled)
        {
            return HealthCheckResult.Healthy("App Check disabled");
        }

        if (string.IsNullOrWhiteSpace(_options.ProjectNumber) || string.IsNullOrWhiteSpace(_options.AppId))
        {
            return HealthCheckResult.Degraded("App Check configuration missing");
        }

        try
        {
            var credential = await GoogleCredential.GetApplicationDefaultAsync(cancellationToken).ConfigureAwait(false);
            credential = credential.CreateScoped(RequiredScopes);

            if (credential is not ITokenAccess tokenAccess)
            {
                LogAppCheckFailure(_logger, "token_access_not_supported", null);
                return HealthCheckResult.Unhealthy("Credential does not support token access.");
            }

            var token = await tokenAccess.GetAccessTokenForRequestAsync(cancellationToken: cancellationToken).ConfigureAwait(false);
            if (string.IsNullOrWhiteSpace(token))
            {
                LogAppCheckFailure(_logger, "empty_token", null);
                return HealthCheckResult.Unhealthy("App Check access token unavailable.");
            }

            return HealthCheckResult.Healthy("App Check credential ready");
        }
        catch (InvalidOperationException ex)
        {
            LogAppCheckFailure(_logger, "misconfigured", ex);
            return HealthCheckResult.Degraded("App Check configuration invalid", ex);
        }
        catch (Exception ex)
        {
            LogAppCheckFailure(_logger, "unexpected", ex);
            return HealthCheckResult.Unhealthy("Unexpected App Check error", ex);
        }
    }
}
