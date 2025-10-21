using System;
using System.Threading.Tasks;
using CringeBank.Api.Authentication;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Serilog.Context;

namespace CringeBank.Api.Security;

public sealed class AppCheckEndpointFilter : IEndpointFilter
{
    private const string FirebaseHeaderName = "X-Firebase-AppCheck";
    private const string AppCheckVerifiedItemKey = "__app_check_verified";

    private static readonly Action<ILogger, Exception?> LogTokenMissing = LoggerMessage.Define(
        LogLevel.Warning,
        new EventId(5400, nameof(LogTokenMissing)),
        "App Check isteği için gerekli token bulunamadı.");

    private static readonly Action<ILogger, string, Exception?> LogTokenInvalid = LoggerMessage.Define<string>(
        LogLevel.Warning,
        new EventId(5401, nameof(LogTokenInvalid)),
        "App Check doğrulaması başarısız: {FailureCode}.");

    private readonly IAppCheckTokenVerifier _verifier;
    private readonly AppCheckOptions _options;
    private readonly ILogger<AppCheckEndpointFilter> _logger;

    public AppCheckEndpointFilter(
        IAppCheckTokenVerifier verifier,
        IOptions<AppCheckOptions> options,
        ILogger<AppCheckEndpointFilter> logger)
    {
        _verifier = verifier ?? throw new ArgumentNullException(nameof(verifier));
        _options = options?.Value ?? throw new ArgumentNullException(nameof(options));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(next);

        if (!_options.Enabled)
        {
            return await next(context).ConfigureAwait(false);
        }

        var endpoint = context.HttpContext.GetEndpoint();
        if (endpoint is null || endpoint.Metadata.GetMetadata<AppCheckEndpointExtensions.AppCheckRequiredMetadata>() is null)
        {
            return await next(context).ConfigureAwait(false);
        }

        if (context.HttpContext.Items.TryGetValue(AppCheckVerifiedItemKey, out var cached) && cached is true)
        {
            return await next(context).ConfigureAwait(false);
        }

        var headerExists = context.HttpContext.Request.Headers.TryGetValue(FirebaseHeaderName, out var headerValues);
        var token = headerExists ? headerValues.ToString() : string.Empty;

        if (string.IsNullOrWhiteSpace(token))
        {
            using (LogContext.PushProperty("SecurityEvent", true))
            {
                LogTokenMissing(_logger, null);
            }

            return Results.Json(new { error = AppCheckVerificationResult.MissingToken.FailureCode }, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await _verifier.VerifyAsync(token, context.HttpContext.RequestAborted).ConfigureAwait(false);
        if (!result.Success)
        {
            var failureCode = result.FailureCode ?? "app_check_invalid";

            using (LogContext.PushProperty("SecurityEvent", true))
            {
                LogTokenInvalid(_logger, failureCode, null);
            }

            return Results.Json(new { error = failureCode }, statusCode: StatusCodes.Status401Unauthorized);
        }

        context.HttpContext.Items[AppCheckVerifiedItemKey] = true;
        return await next(context).ConfigureAwait(false);
    }
}
