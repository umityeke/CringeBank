using System;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CringeBank.Api.Authentication;

public sealed class FirebaseAdminInitializer
{
    private static readonly Action<ILogger, Exception?> LogDefaultCredentials = LoggerMessage.Define(
        LogLevel.Information,
        new EventId(1, nameof(LogDefaultCredentials)),
        "Firebase Admin SDK, default application credentials ile başlatılıyor.");

    private static readonly Action<ILogger, string, Exception?> LogInitializing = LoggerMessage.Define<string>(
        LogLevel.Information,
        new EventId(2, nameof(LogInitializing)),
        "Firebase Admin SDK başlatılıyor ({ProjectId}).");

    private readonly FirebaseAuthenticationOptions _options;
    private readonly ILogger<FirebaseAdminInitializer> _logger;

    public FirebaseAdminInitializer(IOptions<FirebaseAuthenticationOptions> options, ILogger<FirebaseAdminInitializer> logger)
    {
        ArgumentNullException.ThrowIfNull(options);
        ArgumentNullException.ThrowIfNull(logger);

        _options = options.Value;
        _logger = logger;
    }

    public FirebaseApp GetOrCreateApp()
    {
        if (FirebaseApp.DefaultInstance != null)
        {
            return FirebaseApp.DefaultInstance;
        }

        var appOptions = new AppOptions
        {
            ProjectId = _options.ProjectId
        };

        if (!string.IsNullOrWhiteSpace(_options.ServiceAccountJson))
        {
            appOptions.Credential = GoogleCredential.FromJson(_options.ServiceAccountJson);
        }
        else if (!string.IsNullOrWhiteSpace(_options.ServiceAccountKeyPath))
        {
            appOptions.Credential = GoogleCredential.FromFile(_options.ServiceAccountKeyPath);
        }
        else
        {
            LogDefaultCredentials(_logger, null);
            appOptions.Credential = GoogleCredential.GetApplicationDefault();
        }

        if (!string.IsNullOrWhiteSpace(_options.EmulatorHost))
        {
            Environment.SetEnvironmentVariable("FIREBASE_AUTH_EMULATOR_HOST", _options.EmulatorHost);
        }

        LogInitializing(_logger, _options.ProjectId, null);
        return FirebaseApp.Create(appOptions);
    }
}
