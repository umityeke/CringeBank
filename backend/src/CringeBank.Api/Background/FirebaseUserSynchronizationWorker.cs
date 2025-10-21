using System;
using System.Globalization;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Api.Authentication;
using CringeBank.Application;
using CringeBank.Application.Users;
using CringeBank.Application.Users.Commands;
using FirebaseAdmin.Auth;
using Google.Api.Gax;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CringeBank.Api.Background;

public sealed class FirebaseUserSynchronizationWorker : BackgroundService
{
    private static readonly Action<ILogger, Exception?> LogWorkerStarting = LoggerMessage.Define(
        LogLevel.Information,
        new EventId(3000, nameof(LogWorkerStarting)),
        "Firebase kullanıcı senkronizasyon işçisi başlatılıyor.");

    private static readonly Action<ILogger, Exception?> LogWorkerDisabled = LoggerMessage.Define(
        LogLevel.Debug,
        new EventId(3001, nameof(LogWorkerDisabled)),
        "Firebase kullanıcı senkronizasyonu devre dışı. Tekrar denemeden önce 60 saniye beklenecek.");

    private static readonly Action<ILogger, TimeSpan, Exception?> LogStartupDelay = LoggerMessage.Define<TimeSpan>(
        LogLevel.Information,
        new EventId(3002, nameof(LogStartupDelay)),
        "Firebase kullanıcı senkronizasyonu başlangıç gecikmesi: {StartupDelay}.");

    private static readonly Action<ILogger, TimeSpan, Exception?> LogNextInterval = LoggerMessage.Define<TimeSpan>(
        LogLevel.Debug,
        new EventId(3003, nameof(LogNextInterval)),
        "Firebase kullanıcı senkronizasyonu {NextInterval} sonra tekrar çalışacak.");

    private static readonly Action<ILogger, int, string, string, Exception?> LogIterationStart = LoggerMessage.Define<int, string, string>(
        LogLevel.Information,
        new EventId(3004, nameof(LogIterationStart)),
        "Firebase kullanıcı senkronizasyonu çalışıyor (sayfa: {PageSize}, limit: {LimitLabel}, başlangıç page token: {PageToken}).");

    private static readonly Action<ILogger, string, Exception?> LogUserSyncFailed = LoggerMessage.Define<string>(
        LogLevel.Warning,
        new EventId(3005, nameof(LogUserSyncFailed)),
        "Firebase kullanıcısı senkronize edilemedi (UID: {FirebaseUid}).");

    private static readonly Action<ILogger, int, string, Exception?> LogIterationLimitReached = LoggerMessage.Define<int, string>(
        LogLevel.Information,
        new EventId(3006, nameof(LogIterationLimitReached)),
        "Firebase kullanıcı senkronizasyon limitine ulaşıldı. İşlem {ProcessedCount} kullanıcıdan sonra durduruldu. Sonraki token: {NextToken}.");

    private static readonly Action<ILogger, Exception?> LogIterationCompletedFullCycle = LoggerMessage.Define(
        LogLevel.Information,
        new EventId(3007, nameof(LogIterationCompletedFullCycle)),
        "Firebase kullanıcı senkronizasyon turu tamamlandı. Bir sonraki çalıştırmada listedeki baştan başlanacak.");

    private static readonly Action<ILogger, Exception?> LogIterationError = LoggerMessage.Define(
        LogLevel.Error,
        new EventId(3008, nameof(LogIterationError)),
        "Firebase kullanıcı senkronizasyon iterasyonu hata ile sonlandı.");

    private static readonly Action<ILogger, int, Exception?> LogIterationCompleted = LoggerMessage.Define<int>(
        LogLevel.Information,
        new EventId(3009, nameof(LogIterationCompleted)),
        "Firebase kullanıcı senkronizasyon iterasyonu tamamlandı. Toplam {ProcessedCount} kullanıcı işlendi.");

    private static readonly Action<ILogger, Exception?> LogWorkerStopped = LoggerMessage.Define(
        LogLevel.Information,
        new EventId(3010, nameof(LogWorkerStopped)),
        "Firebase kullanıcı senkronizasyon işçisi durduruldu.");

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly FirebaseAuth _firebaseAuth;
    private readonly IOptionsMonitor<FirebaseUserSynchronizationOptions> _optionsMonitor;
    private readonly ILogger<FirebaseUserSynchronizationWorker> _logger;

    private string? _pageToken;
    private bool _startupCompleted;

    public FirebaseUserSynchronizationWorker(
        IServiceScopeFactory scopeFactory,
        FirebaseAuth firebaseAuth,
        IOptionsMonitor<FirebaseUserSynchronizationOptions> optionsMonitor,
        ILogger<FirebaseUserSynchronizationWorker> logger)
    {
        _scopeFactory = scopeFactory ?? throw new ArgumentNullException(nameof(scopeFactory));
        _firebaseAuth = firebaseAuth ?? throw new ArgumentNullException(nameof(firebaseAuth));
        _optionsMonitor = optionsMonitor ?? throw new ArgumentNullException(nameof(optionsMonitor));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        LogWorkerStarting(_logger, null);

        try
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                var options = _optionsMonitor.CurrentValue;

                if (!options.Enabled)
                {
                    LogWorkerDisabled(_logger, null);
                    await DelayAsync(TimeSpan.FromSeconds(60), stoppingToken);
                    continue;
                }

                if (!_startupCompleted)
                {
                    var startupDelay = options.StartupDelay;
                    if (startupDelay > TimeSpan.Zero)
                    {
                        LogStartupDelay(_logger, startupDelay, null);
                        await DelayAsync(startupDelay, stoppingToken);
                    }

                    _startupCompleted = true;

                    if (options.RunOnStartup)
                    {
                        await RunIterationAsync(stoppingToken);
                        continue;
                    }
                }

                var interval = options.Interval;
                if (interval <= TimeSpan.Zero)
                {
                    interval = TimeSpan.FromMinutes(5);
                }

                LogNextInterval(_logger, interval, null);
                await DelayAsync(interval, stoppingToken);

                await RunIterationAsync(stoppingToken);
            }
        }
        catch (OperationCanceledException)
        {
            // Shutdown requested, exit loop gracefully.
        }
        finally
        {
            LogWorkerStopped(_logger, null);
        }
    }

    private static Task DelayAsync(TimeSpan delay, CancellationToken stoppingToken)
    {
        if (delay <= TimeSpan.Zero)
        {
            return Task.CompletedTask;
        }

        return Task.Delay(delay, stoppingToken);
    }

    private async Task RunIterationAsync(CancellationToken stoppingToken)
    {
        var options = _optionsMonitor.CurrentValue;
        var pageSize = options.GetPageSize();
        var maxUsers = options.GetMaxUsersPerIteration();
        var processed = 0;
        var limitLabel = maxUsers == int.MaxValue ? "∞" : maxUsers.ToString(CultureInfo.InvariantCulture);
        var startTokenLabel = string.IsNullOrEmpty(_pageToken) ? "<başlangıç>" : _pageToken;

        LogIterationStart(_logger, pageSize, limitLabel, startTokenLabel, null);

        try
        {
            await using var scope = _scopeFactory.CreateAsyncScope();
            var dispatcher = scope.ServiceProvider.GetRequiredService<IDispatcher>();
            var profileFactory = scope.ServiceProvider.GetRequiredService<FirebaseUserProfileFactory>();

            var listOptions = new ListUsersOptions
            {
                PageSize = pageSize,
                PageToken = _pageToken
            };

            var pagedEnumerable = _firebaseAuth.ListUsersAsync(listOptions);

            await foreach (var page in pagedEnumerable.AsRawResponses().WithCancellation(stoppingToken))
            {
                _pageToken = page.NextPageToken;

                foreach (var user in page.Users)
                {
                    stoppingToken.ThrowIfCancellationRequested();

                    try
                    {
                        var profile = profileFactory.Create(user);
                        var command = new SynchronizeFirebaseUserCommand(profile);
                        await dispatcher.SendAsync<SynchronizeFirebaseUserCommand, UserSynchronizationResult>(command, stoppingToken);
                        processed++;
                    }
                    catch (Exception syncException)
                    {
                        LogUserSyncFailed(_logger, user.Uid, syncException);
                    }

                    if (processed >= maxUsers)
                    {
                        var nextTokenLabel = string.IsNullOrEmpty(_pageToken) ? "<başlangıç>" : _pageToken;
                        LogIterationLimitReached(_logger, processed, nextTokenLabel, null);
                        return;
                    }
                }

                if (string.IsNullOrEmpty(_pageToken))
                {
                    LogIterationCompletedFullCycle(_logger, null);
                    break;
                }
            }
        }
        catch (OperationCanceledException)
        {
            // cancellation requested, do not log as error
            throw;
        }
        catch (Exception ex)
        {
            LogIterationError(_logger, ex);
        }
        finally
        {
            LogIterationCompleted(_logger, processed, null);
        }
    }
}
