using System;
using Microsoft.Extensions.Logging;
using Serilog.Context;

namespace CringeBank.Api.Security;

public static class SecurityLogEvents
{
    private static readonly Action<ILogger, string, string, string, string, string, Exception?> LogPasswordSignInAttempt = LoggerMessage.Define<string, string, string, string, string>(
        LogLevel.Information,
        new EventId(5100, nameof(LogPasswordSignInAttempt)),
        "PasswordSignIn identifierHash={IdentifierHash}, outcome={Outcome}, requiresMfa={RequiresMfa}, deviceHash={DeviceHash}, ipHash={IpHash}");

    private static readonly Action<ILogger, string, string, Exception?> LogRefreshTokenRevoked = LoggerMessage.Define<string, string>(
        LogLevel.Information,
        new EventId(5101, nameof(LogRefreshTokenRevoked)),
        "RefreshTokenRevoke refreshHash={RefreshHash}, outcome={Outcome}");

    public static void LogPasswordSignIn(
        ILogger logger,
        string identifierHash,
        bool success,
        bool requiresMfa,
        string? failureCode,
        string deviceIdHash,
        string ipHash)
    {
        if (logger is null)
        {
            throw new ArgumentNullException(nameof(logger));
        }

        var outcome = success
            ? requiresMfa ? "MfaChallenge" : "Success"
            : string.IsNullOrWhiteSpace(failureCode) ? "Failure" : failureCode!;

        var requiresMfaFlag = requiresMfa ? "true" : "false";
        var deviceHashValue = string.IsNullOrWhiteSpace(deviceIdHash) ? "none" : deviceIdHash;
        var ipHashValue = string.IsNullOrWhiteSpace(ipHash) ? "none" : ipHash;

        using (LogContext.PushProperty("SecurityEvent", true))
        {
            LogPasswordSignInAttempt(logger, identifierHash, outcome, requiresMfaFlag, deviceHashValue, ipHashValue, null);
        }
    }

    public static void LogRefreshTokenRevocation(
        ILogger logger,
        string refreshTokenHash,
        bool success,
        string? failureCode)
    {
        if (logger is null)
        {
            throw new ArgumentNullException(nameof(logger));
        }

        var outcome = success
            ? "Success"
            : string.IsNullOrWhiteSpace(failureCode) ? "Failure" : failureCode!;

        using (LogContext.PushProperty("SecurityEvent", true))
        {
            LogRefreshTokenRevoked(logger, string.IsNullOrWhiteSpace(refreshTokenHash) ? "none" : refreshTokenHash, outcome, null);
        }
    }
}
