using System.Security.Cryptography;
using System.Text;
using System.Threading;
using CringeBank.Api.Auth;
using CringeBank.Application;
using CringeBank.Application.Auth.Commands;
using CringeBank.Api.Security;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace CringeBank.Api.Auth;

public static class AuthEndpoints
{
    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/auth");
        group.WithTags("Auth");
        group.AllowAnonymous();
        group.RequireAppCheck();

        group.MapPost("/login", async (
            PasswordSignInRequest request,
            IDispatcher dispatcher,
            ILogger<SecurityLoggerMarker> securityLogger,
            CancellationToken cancellationToken) =>
        {
            var command = new PasswordSignInCommand(request.Identifier, request.Password, request.DeviceIdHash, request.IpHash);
            var result = await dispatcher.SendAsync<PasswordSignInCommand, PasswordSignInResult>(command, cancellationToken);

            var identifierHash = ComputeSha256(request.Identifier);
            var deviceHash = request.DeviceIdHash ?? string.Empty;
            var ipHash = request.IpHash ?? string.Empty;
            SecurityLogEvents.LogPasswordSignIn(securityLogger, identifierHash, result.Success, result.RequiresMfa, result.FailureCode, deviceHash, ipHash);

            var response = new PasswordSignInResponse(
                result.Success,
                result.AccessToken,
                result.RefreshToken,
                result.RefreshTokenExpiresAtUtc,
                result.RequiresMfa,
                result.MfaToken,
                result.FailureCode);

            return Results.Ok(response);
        })
        .WithName("AuthPasswordLogin");

        group.MapPost("/refresh", async (RefreshTokenRequest request, IDispatcher dispatcher, CancellationToken cancellationToken) =>
        {
            var command = new RefreshTokenCommand(request.RefreshToken);
            var result = await dispatcher.SendAsync<RefreshTokenCommand, RefreshTokenResult>(command, cancellationToken);

            var response = new RefreshTokenResponse(
                result.Success,
                result.AccessToken,
                result.RefreshToken,
                result.RefreshTokenExpiresAtUtc,
                result.FailureCode);

            return Results.Ok(response);
        })
        .WithName("AuthRefresh");

        group.MapPost("/logout", async (
            RevokeRefreshTokenRequest request,
            IDispatcher dispatcher,
            ILogger<SecurityLoggerMarker> securityLogger,
            CancellationToken cancellationToken) =>
        {
            var command = new RevokeRefreshTokenCommand(request.RefreshToken);
            var result = await dispatcher.SendAsync<RevokeRefreshTokenCommand, RevokeRefreshTokenResult>(command, cancellationToken);

            var refreshTokenHash = ComputeSha256(request.RefreshToken);
            SecurityLogEvents.LogRefreshTokenRevocation(securityLogger, refreshTokenHash, result.Success, result.FailureCode);

            var response = new RevokeRefreshTokenResponse(result.Success, result.FailureCode);

            return Results.Ok(response);
        })
        .WithName("AuthLogout");

        group.MapPost("/magic-link", async (SendMagicLinkRequest request, IDispatcher dispatcher, IHostEnvironment environment, CancellationToken cancellationToken) =>
        {
            var command = new SendMagicLinkCommand(request.Email);
            var result = await dispatcher.SendAsync<SendMagicLinkCommand, SendMagicLinkResult>(command, cancellationToken);

            var debugToken = environment.IsDevelopment() ? result.TokenForDebug : null;
            var response = new SendMagicLinkResponse(result.Sent, debugToken);

            return Results.Ok(response);
        })
        .WithName("AuthSendMagicLink");

        group.MapPost("/magic-link/redeem", async (RedeemMagicLinkRequest request, IDispatcher dispatcher, CancellationToken cancellationToken) =>
        {
            var command = new RedeemMagicLinkCommand(request.Token);
            var result = await dispatcher.SendAsync<RedeemMagicLinkCommand, RedeemMagicLinkResult>(command, cancellationToken);

            var response = new RedeemMagicLinkResponse(
                result.Success,
                result.AccessToken,
                result.RefreshToken,
                result.RefreshTokenExpiresAtUtc,
                result.FailureCode);

            return Results.Ok(response);
        })
        .WithName("AuthRedeemMagicLink");

        group.MapPost("/mfa/verify", async (VerifyMfaRequest request, IDispatcher dispatcher, CancellationToken cancellationToken) =>
        {
            var command = new VerifyMfaCommand(request.Token, request.Code);
            var result = await dispatcher.SendAsync<VerifyMfaCommand, VerifyMfaResult>(command, cancellationToken);

            var response = new VerifyMfaResponse(
                result.Success,
                result.AccessToken,
                result.RefreshToken,
                result.RefreshTokenExpiresAtUtc,
                result.FailureCode);

            return Results.Ok(response);
        })
        .WithName("AuthVerifyMfa");

        return endpoints;
    }

    private static string ComputeSha256(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return "none";
        }

        var inputBytes = Encoding.UTF8.GetBytes(value);
        var hash = SHA256.HashData(inputBytes);
        return Convert.ToHexString(hash);
    }
}
