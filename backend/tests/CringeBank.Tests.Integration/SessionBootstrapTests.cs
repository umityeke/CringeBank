namespace CringeBank.Tests.Integration;

using System;
using System.Net;
using System.Net.Http.Json;
using System.Threading.Tasks;
using CringeBank.Api.Session;
using CringeBank.Tests.Integration.Infrastructure;

public sealed class SessionBootstrapTests : IClassFixture<TestApplicationFactory>
{
    private readonly TestApplicationFactory _factory;

    public SessionBootstrapTests(TestApplicationFactory factory)
    {
        _factory = factory ?? throw new ArgumentNullException(nameof(factory));
    }

    [Fact]
    public async Task session_bootstrap_returns_authenticated_profile()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-UserId", TestAuthDefaults.DefaultUserId.ToString());

    using var content = JsonContent.Create(new { });
    using var response = await client.PostAsync("/api/session/bootstrap", content);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<SessionBootstrapResponse>();
        Assert.NotNull(payload);

        Assert.Equal(TestAuthDefaults.DefaultFirebaseUid, payload!.FirebaseUid);
        Assert.Equal(TestAuthDefaults.DefaultEmail, payload.Email);
        Assert.True(payload.EmailVerified);
        Assert.Equal(2, payload.ClaimsVersion);
        Assert.NotEqual(Guid.Empty, payload.UserId);
        Assert.NotNull(payload.LastSyncedAtUtc);
    }
}
