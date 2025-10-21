using System;
using System.Threading;
using System.Threading.Tasks;
using FirebaseAdmin.Auth;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;

namespace CringeBank.Api.HealthChecks;

public sealed class FirebaseAuthHealthCheck : IHealthCheck
{
    private const string ProbeUserId = "health-check-placeholder-user";

    private static readonly Action<ILogger, string, Exception?> LogFirebaseFailure = LoggerMessage.Define<string>(
        LogLevel.Error,
        new EventId(5501, nameof(LogFirebaseFailure)),
        "Firebase Auth health check failed: {Reason}.");

    private readonly FirebaseAuth _firebaseAuth;
    private readonly ILogger<FirebaseAuthHealthCheck> _logger;

    public FirebaseAuthHealthCheck(FirebaseAuth firebaseAuth, ILogger<FirebaseAuthHealthCheck> logger)
    {
        _firebaseAuth = firebaseAuth ?? throw new ArgumentNullException(nameof(firebaseAuth));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(context);

        try
        {
            _ = await _firebaseAuth.GetUserAsync(ProbeUserId, cancellationToken).ConfigureAwait(false);
            return HealthCheckResult.Healthy("Firebase Auth reachable");
        }
        catch (FirebaseAuthException ex) when (ex.AuthErrorCode == AuthErrorCode.UserNotFound)
        {
            return HealthCheckResult.Healthy("Firebase Auth reachable");
        }
        catch (FirebaseAuthException ex)
        {
            var reason = ex.AuthErrorCode.ToString() ?? "unknown";
            LogFirebaseFailure(_logger, reason, ex);
            return HealthCheckResult.Unhealthy($"Firebase Auth error: {ex.AuthErrorCode}", ex);
        }
        catch (Exception ex)
        {
            LogFirebaseFailure(_logger, "unexpected", ex);
            return HealthCheckResult.Unhealthy("Unexpected Firebase Auth error", ex);
        }
    }
}
