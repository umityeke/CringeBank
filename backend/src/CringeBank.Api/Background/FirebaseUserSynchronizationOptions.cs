using System;

namespace CringeBank.Api.Background;

public sealed class FirebaseUserSynchronizationOptions
{
    private const int MinimumIntervalSeconds = 60;
    private const int MaximumIntervalSeconds = 86_400;
    private const int DefaultIntervalSeconds = 300;
    private const int MaximumPageSize = 1000;

    public bool Enabled { get; init; } = true;

    public int IntervalSeconds { get; init; } = DefaultIntervalSeconds;

    public int StartupDelaySeconds { get; init; } = 30;

    public int PageSize { get; init; } = 500;

    public int MaxUsersPerIteration { get; init; } = 5000;

    public bool RunOnStartup { get; init; } = true;

    public TimeSpan Interval => TimeSpan.FromSeconds(Math.Clamp(IntervalSeconds, MinimumIntervalSeconds, MaximumIntervalSeconds));

    public TimeSpan StartupDelay => TimeSpan.FromSeconds(Math.Max(StartupDelaySeconds, 0));

    public int GetPageSize()
    {
        return Math.Clamp(PageSize, 1, MaximumPageSize);
    }

    public int GetMaxUsersPerIteration()
    {
        if (MaxUsersPerIteration <= 0)
        {
            return int.MaxValue;
        }

        return Math.Max(1, MaxUsersPerIteration);
    }
}
