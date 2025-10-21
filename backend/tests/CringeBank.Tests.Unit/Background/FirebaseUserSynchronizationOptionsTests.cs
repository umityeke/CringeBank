using System;
using CringeBank.Api.Background;

namespace CringeBank.Tests.Unit.Background;

public sealed class FirebaseUserSynchronizationOptionsTests
{
    [Fact]
    public void Interval_Clamps_ToConfiguredBounds()
    {
        var belowMinimum = new FirebaseUserSynchronizationOptions { IntervalSeconds = -10 };
        var aboveMaximum = new FirebaseUserSynchronizationOptions { IntervalSeconds = 200_000 };

        Assert.Equal(TimeSpan.FromSeconds(60), belowMinimum.Interval);
        Assert.Equal(TimeSpan.FromSeconds(86_400), aboveMaximum.Interval);
    }

    [Fact]
    public void StartupDelay_IsNeverNegative()
    {
        var options = new FirebaseUserSynchronizationOptions { StartupDelaySeconds = -30 };

        Assert.Equal(TimeSpan.Zero, options.StartupDelay);
    }

    [Fact]
    public void GetPageSize_ClampsToValidRange()
    {
        var tooSmall = new FirebaseUserSynchronizationOptions { PageSize = 0 };
        var tooLarge = new FirebaseUserSynchronizationOptions { PageSize = 5_000 };
        var withinBounds = new FirebaseUserSynchronizationOptions { PageSize = 250 };

        Assert.Equal(1, tooSmall.GetPageSize());
        Assert.Equal(1_000, tooLarge.GetPageSize());
        Assert.Equal(250, withinBounds.GetPageSize());
    }

    [Fact]
    public void GetMaxUsersPerIteration_ReturnsIntMaxWhenZeroOrNegative()
    {
        var zero = new FirebaseUserSynchronizationOptions { MaxUsersPerIteration = 0 };
        var negative = new FirebaseUserSynchronizationOptions { MaxUsersPerIteration = -10 };
        var positive = new FirebaseUserSynchronizationOptions { MaxUsersPerIteration = 1234 };

        Assert.Equal(int.MaxValue, zero.GetMaxUsersPerIteration());
        Assert.Equal(int.MaxValue, negative.GetMaxUsersPerIteration());
        Assert.Equal(1234, positive.GetMaxUsersPerIteration());
    }
}
