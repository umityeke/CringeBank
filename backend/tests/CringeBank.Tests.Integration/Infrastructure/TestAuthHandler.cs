namespace CringeBank.Tests.Integration.Infrastructure;

using System;
using System.Globalization;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

public static class TestAuthDefaults
{
    public const string AuthenticationScheme = "Test";
    public static readonly Guid DefaultUserId = Guid.Parse("11111111-1111-1111-1111-111111111111");
    public const string DisplayName = "Test User";
    public const string DefaultEmail = "test.user@cringebank.test";

    public static string DefaultFirebaseUid => DefaultUserId.ToString("N", CultureInfo.InvariantCulture);
}

public sealed class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : base(options, logger, encoder)
    {
    }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var userId = TestAuthDefaults.DefaultUserId;
        if (Request.Headers.TryGetValue("X-Test-UserId", out var userIdHeader) && Guid.TryParse(userIdHeader, out var parsedUserId))
        {
            userId = parsedUserId;
        }

        var firebaseUid = userId.ToString("N", CultureInfo.InvariantCulture);
        var email = TestAuthDefaults.DefaultEmail;

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim("uid", userId.ToString()),
            new Claim("firebase_uid", firebaseUid),
            new Claim(ClaimTypes.Email, email),
            new Claim("email", email),
            new Claim("email_verified", "true"),
            new Claim("claims_version", "2"),
            new Claim(ClaimTypes.Name, TestAuthDefaults.DisplayName),
            new Claim("app_version", "1.0.0"),
            new Claim("auth_time", DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture)),
            new Claim("user_status", "Active"),
            new Claim(ClaimTypes.Role, "user")
        };

        var identity = new ClaimsIdentity(claims, Scheme.Name);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, Scheme.Name);

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
