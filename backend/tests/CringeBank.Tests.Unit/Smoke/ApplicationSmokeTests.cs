using CringeBank.Application;
using Microsoft.Extensions.DependencyInjection;

namespace CringeBank.Tests.Unit.Smoke;

public sealed class ApplicationSmokeTests
{
    [Fact]
    [Trait("Category", "Smoke")]
    public void AddApplicationCore_ShouldResolveDispatcher()
    {
        var services = new ServiceCollection();

        services.AddApplicationCore();

        using var provider = services.BuildServiceProvider();

        var dispatcher = provider.GetRequiredService<IDispatcher>();

        Assert.NotNull(dispatcher);
    }
}
