using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using CringeBank.Api.Authentication;

namespace CringeBank.Api.Security;

public sealed class FirebaseAppCheckTokenVerifier : IAppCheckTokenVerifier
{
    public const string HttpClientName = "FirebaseAppCheck";

    private static readonly TimeSpan FailureCacheDuration = TimeSpan.FromSeconds(30);
    private static readonly string[] RequiredScopes =
    {
        "https://www.googleapis.com/auth/firebase",
        "https://www.googleapis.com/auth/cloud-platform"
    };

    private static readonly Action<ILogger, Exception?> LogConfigurationMissing = LoggerMessage.Define(
        LogLevel.Warning,
        new EventId(5300, nameof(LogConfigurationMissing)),
        "App Check doğrulaması etkin, ancak yapılandırma eksik.");

    private static readonly Action<ILogger, string, string, Exception?> LogVerificationFailed = LoggerMessage.Define<string, string>(
        LogLevel.Warning,
        new EventId(5301, nameof(LogVerificationFailed)),
        "App Check doğrulaması başarısız (Status: {StatusCode}, Error: {ErrorCode}).");

    private static readonly Action<ILogger, Exception?> LogUnexpectedError = LoggerMessage.Define(
        LogLevel.Error,
        new EventId(5302, nameof(LogUnexpectedError)),
        "App Check doğrulaması sırasında beklenmeyen hata oluştu.");

    private static readonly Action<ILogger, string?, Exception?> LogErrorParseFailed = LoggerMessage.Define<string?>(
        LogLevel.Debug,
        new EventId(5303, nameof(LogErrorParseFailed)),
        "App Check hata cevabı çözümlenemedi: {Body}");

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IMemoryCache _cache;
    private readonly ILogger<FirebaseAppCheckTokenVerifier> _logger;
    private readonly AppCheckOptions _options;
    private readonly JsonSerializerOptions _serializerOptions = new(JsonSerializerDefaults.Web);
    private readonly Lazy<Task<GoogleCredential>> _credentialLoader;

    public FirebaseAppCheckTokenVerifier(
        IHttpClientFactory httpClientFactory,
        IOptions<AppCheckOptions> options,
        IMemoryCache cache,
        ILogger<FirebaseAppCheckTokenVerifier> logger)
    {
        _httpClientFactory = httpClientFactory ?? throw new ArgumentNullException(nameof(httpClientFactory));
        _cache = cache ?? throw new ArgumentNullException(nameof(cache));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _options = options?.Value ?? throw new ArgumentNullException(nameof(options));

        _credentialLoader = new Lazy<Task<GoogleCredential>>(async () =>
        {
            var credential = await GoogleCredential.GetApplicationDefaultAsync().ConfigureAwait(false);
            return credential.CreateScoped(RequiredScopes);
        });
    }

    public async Task<AppCheckVerificationResult> VerifyAsync(string token, CancellationToken cancellationToken = default)
    {
        if (!_options.Enabled)
        {
            return AppCheckVerificationResult.SuccessResult;
        }

        if (string.IsNullOrWhiteSpace(_options.ProjectNumber) || string.IsNullOrWhiteSpace(_options.AppId))
        {
            LogConfigurationMissing(_logger, null);
            return new AppCheckVerificationResult(false, "app_check_configuration_missing");
        }

        if (string.IsNullOrWhiteSpace(token))
        {
            return AppCheckVerificationResult.MissingToken;
        }

        if (_cache.TryGetValue<AppCheckVerificationResult>(token, out var cached) && cached is not null)
        {
            return cached;
        }

        try
        {
            var accessToken = await GetAccessTokenAsync(cancellationToken).ConfigureAwait(false);
            var requestUri = $"https://firebaseappcheck.googleapis.com/v1beta/projects/{_options.ProjectNumber}/apps/{_options.AppId}:verifyAppCheckToken";

            var httpClient = _httpClientFactory.CreateClient(HttpClientName);
            using var httpRequest = new HttpRequestMessage(HttpMethod.Post, requestUri)
            {
                Content = JsonContent.Create(new VerifyRequest(token))
            };

            httpRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

            using var response = await httpClient.SendAsync(httpRequest, cancellationToken).ConfigureAwait(false);

            if (response.IsSuccessStatusCode)
            {
                var ttlSeconds = _options.CacheTtlSeconds > 0 ? _options.CacheTtlSeconds : 300;
                var cacheDuration = TimeSpan.FromSeconds(Math.Max(30, ttlSeconds));
                _cache.Set(token, AppCheckVerificationResult.SuccessResult, cacheDuration);
                return AppCheckVerificationResult.SuccessResult;
            }

            var errorBody = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            var errorCode = ParseErrorCode(errorBody);
            LogVerificationFailed(_logger, response.StatusCode.ToString(), errorCode ?? "unknown", null);

            var failureResult = new AppCheckVerificationResult(false, errorCode ?? "app_check_invalid");
            _cache.Set(token, failureResult, FailureCacheDuration);
            return failureResult;
        }
        catch (Exception ex) when (!cancellationToken.IsCancellationRequested)
        {
            LogUnexpectedError(_logger, ex);
            return new AppCheckVerificationResult(false, "app_check_error");
        }
    }

    private async Task<string> GetAccessTokenAsync(CancellationToken cancellationToken)
    {
        var credential = await _credentialLoader.Value.ConfigureAwait(false);

        if (credential is not ITokenAccess tokenAccess)
        {
            throw new InvalidOperationException("Google credential token erişimini desteklemiyor.");
        }

        var token = await tokenAccess.GetAccessTokenForRequestAsync(cancellationToken: cancellationToken).ConfigureAwait(false);
        if (string.IsNullOrWhiteSpace(token))
        {
            throw new InvalidOperationException("Google access token alınamadı.");
        }

        return token;
    }

    private string? ParseErrorCode(string? errorBody)
    {
        if (string.IsNullOrWhiteSpace(errorBody))
        {
            return null;
        }

        try
        {
            var payload = JsonSerializer.Deserialize<GoogleErrorResponse>(errorBody, _serializerOptions);
            return payload?.Error?.Status?.ToLowerInvariant();
        }
        catch (JsonException ex)
        {
            LogErrorParseFailed(_logger, errorBody, ex);
            return null;
        }
    }

    private readonly record struct VerifyRequest(string Token);

    private sealed record GoogleErrorResponse(GoogleError? Error);

    private sealed record GoogleError(string? Status, string? Message, int? Code);
}
