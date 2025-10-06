namespace CringeBank.Api;

using System;
using System.Globalization;
using System.Reflection;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using System.Linq;
using System.IdentityModel.Tokens.Jwt;
using Claim = System.Security.Claims.Claim;
using ClaimsIdentity = System.Security.Claims.ClaimsIdentity;
using CringeBank.Application.Users;
using CringeBank.Api.Authentication;
using CringeBank.Api.Session;
using CringeBank.Infrastructure.Persistence;
using CringeBank.Infrastructure.Users;
using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Google.Apis.Auth.OAuth2;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Serilog;

public sealed partial class Program
{
    private const string UserSynchronizationResultItemKey = "__cringebank_user_sync_result";

    private static readonly Action<Microsoft.Extensions.Logging.ILogger, string, Exception?> LogEmailNotVerified = LoggerMessage.Define<string>(
        LogLevel.Warning,
        new EventId(1000, nameof(LogEmailNotVerified)),
        "Firebase ID token email doğrulanmamış (UID: {Uid}).");

    private static readonly Action<Microsoft.Extensions.Logging.ILogger, string, int, int, Exception?> LogClaimsVersionMismatch = LoggerMessage.Define<string, int, int>(
        LogLevel.Warning,
        new EventId(1001, nameof(LogClaimsVersionMismatch)),
        "Firebase ID token claims_version eşleşmedi (UID: {Uid}, token: {TokenVersion}, minimum: {MinimumVersion}).");

    private static readonly Action<Microsoft.Extensions.Logging.ILogger, string, Exception?> LogFirebaseVerificationFailed = LoggerMessage.Define<string>(
        LogLevel.Warning,
        new EventId(1002, nameof(LogFirebaseVerificationFailed)),
        "Firebase ID token doğrulaması başarısız (kod: {Code}).");

    private static readonly Action<Microsoft.Extensions.Logging.ILogger, string, Exception?> LogJwtAuthenticationFailed = LoggerMessage.Define<string>(
        LogLevel.Warning,
        new EventId(1003, nameof(LogJwtAuthenticationFailed)),
        "JWT kimlik doğrulaması başarısız oldu: {Message}.");

    public static void Main(string[] args)
    {
        BuildWebApplication(args).Run();
    }

    public static WebApplication BuildWebApplication(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        ConfigureConfiguration(builder);
        ConfigureLogging(builder);
        ConfigureServices(builder);

        var app = builder.Build();
        ConfigurePipeline(app);

        return app;
    }

    private static void ConfigureConfiguration(WebApplicationBuilder builder)
    {
        builder.Configuration
            .SetBasePath(builder.Environment.ContentRootPath)
            .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
            .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: true);

        if (builder.Environment.IsDevelopment())
        {
            builder.Configuration.AddUserSecrets<Program>(optional: true);
        }

        builder.Configuration.AddEnvironmentVariables(prefix: "CRINGEBANK_");
    }

    private static void ConfigureLogging(WebApplicationBuilder builder)
    {
        builder.Host.UseSerilog((context, services, loggerConfiguration) =>
        {
            loggerConfiguration
                .ReadFrom.Configuration(context.Configuration)
                .ReadFrom.Services(services)
                .Enrich.FromLogContext();
        });
    }

    private static void ConfigureServices(WebApplicationBuilder builder)
    {
        var services = builder.Services;
        var configuration = builder.Configuration;

        services.AddProblemDetails(options =>
        {
            options.CustomizeProblemDetails = ctx =>
            {
                if (ctx.ProblemDetails.Status >= StatusCodes.Status500InternalServerError)
                {
                    ctx.ProblemDetails.Title = "An unexpected error occurred.";
                    ctx.ProblemDetails.Extensions["traceId"] = ctx.HttpContext.TraceIdentifier;
                }
            };
        });

        var sqlConnectionString = configuration.GetConnectionString("Sql");

        if (string.IsNullOrWhiteSpace(sqlConnectionString))
        {
            throw new InvalidOperationException(
                "Connection string 'Sql' not found. Configure it via appsettings, secrets, or the CRINGEBANK__CONNECTIONSTRINGS__SQL environment variable.");
        }

        services.AddDbContext<CringeBankDbContext>(options =>
            options.UseSqlServer(sqlConnectionString, sql =>
            {
                sql.MigrationsAssembly(typeof(CringeBankDbContext).Assembly.FullName);
                sql.MigrationsHistoryTable("__EFMigrationsHistory", CringeBankDbContext.Schema);
                sql.EnableRetryOnFailure();
            }));

        services.AddEndpointsApiExplorer();
        services.AddSwaggerGen();
        services.AddHealthChecks()
            .AddCheck<CringeBankDbContextHealthCheck>("database");

        var allowedOrigins = configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? Array.Empty<string>();

        services.AddCors(options =>
        {
            options.AddPolicy("Default", policy =>
            {
                if (allowedOrigins.Length == 0)
                {
                    policy
                        .AllowAnyOrigin()
                        .AllowAnyHeader()
                        .AllowAnyMethod();
                }
                else
                {
                    policy
                        .WithOrigins(allowedOrigins)
                        .AllowAnyHeader()
                        .AllowAnyMethod()
                        .AllowCredentials();
                }
            });
        });

        services.AddScoped<FirebaseUserProfileFactory>();
        services.AddScoped<IUserSynchronizationService, UserSynchronizationService>();

        ConfigureAuthentication(services, configuration);
    }

    private static void ConfigureAuthentication(IServiceCollection services, ConfigurationManager configuration)
    {
        var firebaseSection = configuration.GetSection("Authentication:Firebase");

        services.Configure<FirebaseAuthenticationOptions>(firebaseSection);

        var firebaseOptions = firebaseSection.Get<FirebaseAuthenticationOptions>();

        if (firebaseOptions is null)
        {
            throw new InvalidOperationException("Authentication:Firebase yapılandırması eksik.");
        }

        if (string.IsNullOrWhiteSpace(firebaseOptions.ProjectId))
        {
            throw new InvalidOperationException("Authentication:Firebase:ProjectId değeri ayarlanmalıdır.");
        }

        services.AddSingleton<FirebaseAdminInitializer>();
        services.AddSingleton(provider =>
        {
            var initializer = provider.GetRequiredService<FirebaseAdminInitializer>();
            return initializer.GetOrCreateApp();
        });

        services.AddSingleton(provider =>
        {
            var app = provider.GetRequiredService<FirebaseApp>();
            return FirebaseAuth.GetAuth(app);
        });

        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.RequireHttpsMetadata = true;
                options.SaveToken = true;
                options.Authority = $"https://securetoken.google.com/{firebaseOptions.ProjectId}";
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = $"https://securetoken.google.com/{firebaseOptions.ProjectId}",
                    ValidateAudience = true,
                    ValidAudience = firebaseOptions.ProjectId,
                    ValidateLifetime = true,
                    RequireExpirationTime = true,
                    ClockSkew = firebaseOptions.TokenClockSkew
                };

                options.Events = new JwtBearerEvents
                {
                    OnTokenValidated = async context =>
                    {
                        var logger = context.HttpContext.RequestServices.GetRequiredService<ILogger<Program>>();
                        var firebaseAuth = context.HttpContext.RequestServices.GetRequiredService<FirebaseAuth>();
                        var currentOptions = context.HttpContext.RequestServices.GetRequiredService<IOptions<FirebaseAuthenticationOptions>>().Value;
                        var profileFactory = context.HttpContext.RequestServices.GetRequiredService<FirebaseUserProfileFactory>();
                        var synchronizationService = context.HttpContext.RequestServices.GetRequiredService<IUserSynchronizationService>();

                        try
                        {
                            if (context.SecurityToken is not JwtSecurityToken jwt)
                            {
                                context.Fail("Geçersiz JWT.");
                                return;
                            }

                            var decodedToken = await firebaseAuth.VerifyIdTokenAsync(jwt.RawData, currentOptions.CheckRevoked, context.HttpContext.RequestAborted);

                            if (currentOptions.RequireEmailVerified)
                            {
                                var emailVerified = false;

                                if (decodedToken.Claims.TryGetValue("email_verified", out var emailVerifiedObj))
                                {
                                    emailVerified = emailVerifiedObj switch
                                    {
                                        bool flag => flag,
                                        string str when bool.TryParse(str, out var parsed) => parsed,
                                        _ => false
                                    };
                                }

                                if (!emailVerified)
                                {
                                    LogEmailNotVerified((Microsoft.Extensions.Logging.ILogger)logger, decodedToken.Uid, null);
                                    context.Fail("E-posta doğrulanmamış.");
                                    return;
                                }
                            }

                            if (currentOptions.MinimumClaimsVersion > 0)
                            {
                                var claimsVersion = 0;
                                if (decodedToken.Claims.TryGetValue("claims_version", out var claimsVersionObj))
                                {
                                    _ = int.TryParse(Convert.ToString(claimsVersionObj, CultureInfo.InvariantCulture), out claimsVersion);
                                }

                                if (claimsVersion < currentOptions.MinimumClaimsVersion)
                                {
                                    LogClaimsVersionMismatch((Microsoft.Extensions.Logging.ILogger)logger, decodedToken.Uid, claimsVersion, currentOptions.MinimumClaimsVersion, null);
                                    context.Fail("claims_version yükseltilmeli.");
                                    return;
                                }
                            }

                            if (context.Principal?.Identities.FirstOrDefault() is not ClaimsIdentity identity)
                            {
                                context.Fail("Kimlik oluşturulamadı.");
                                return;
                            }

                            identity.AddClaim(new Claim("firebase_uid", decodedToken.Uid));

                            if (decodedToken.Claims.TryGetValue("claims_version", out var claimsVersionClaim))
                            {
                                var value = Convert.ToString(claimsVersionClaim, CultureInfo.InvariantCulture);
                                if (!string.IsNullOrWhiteSpace(value))
                                {
                                    identity.AddClaim(new Claim("claims_version", value));
                                }
                            }

                            if (decodedToken.Claims.TryGetValue("role", out var roleValue))
                            {
                                var value = Convert.ToString(roleValue, CultureInfo.InvariantCulture);
                                if (!string.IsNullOrWhiteSpace(value))
                                {
                                    identity.AddClaim(new Claim(ClaimTypes.Role, value));
                                }
                            }

                            if (decodedToken.Claims.TryGetValue("user_status", out var statusValue))
                            {
                                var value = Convert.ToString(statusValue, CultureInfo.InvariantCulture);
                                if (!string.IsNullOrWhiteSpace(value))
                                {
                                    identity.AddClaim(new Claim("user_status", value));
                                }
                            }

                            if (context.Principal is null)
                            {
                                context.Fail("Kimlik doğrulama sonucu bulunamadı.");
                                return;
                            }

                            var profile = profileFactory.Create(context.Principal);
                            var syncResult = await synchronizationService.SynchronizeAsync(profile, context.HttpContext.RequestAborted);
                            context.HttpContext.Items[UserSynchronizationResultItemKey] = syncResult;
                        }
                        catch (FirebaseAuthException ex)
                        {
                            LogFirebaseVerificationFailed((Microsoft.Extensions.Logging.ILogger)logger, Convert.ToString(ex.AuthErrorCode, CultureInfo.InvariantCulture) ?? string.Empty, ex);
                            context.Fail("Firebase token doğrulaması başarısız oldu.");
                        }
                    },
                    OnAuthenticationFailed = context =>
                    {
                        var logger = context.HttpContext.RequestServices.GetRequiredService<ILogger<Program>>();
                        var message = context.Exception?.Message ?? "Bilinmeyen hata";
                        LogJwtAuthenticationFailed((Microsoft.Extensions.Logging.ILogger)logger, message, null);
                        return Task.CompletedTask;
                    }
                };
            });

        services.AddAuthorization();
    }

    private static SessionBootstrapResponse ToSessionBootstrapResponse(UserSynchronizationResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        return new SessionBootstrapResponse(
            result.UserId,
            result.FirebaseUid,
            result.Email,
            result.EmailVerified,
            result.ClaimsVersion,
            result.Status.ToString(),
            result.DisplayName,
            result.ProfileImageUrl,
            result.PhoneNumber,
            result.LastLoginAtUtc,
            result.LastSyncedAtUtc,
            result.LastSeenAppVersion);
    }

    private static void ConfigurePipeline(WebApplication app)
    {
        app.UseSerilogRequestLogging();

        app.UseExceptionHandler();
        app.UseStatusCodePages();

        if (!app.Environment.IsDevelopment())
        {
            app.UseHsts();
        }

        app.UseHttpsRedirection();
        app.UseAuthentication();
        app.UseCors("Default");
        app.UseAuthorization();

        var swaggerEnabled = app.Configuration.GetValue<bool?>("Swagger:Enabled") ?? app.Environment.IsDevelopment();
        if (swaggerEnabled)
        {
            app.UseSwagger();
            app.UseSwaggerUI();
        }

        app.MapHealthChecks("/health/ready");
        app.MapGet("/health/live", () => Results.Ok(new { status = "Healthy" }))
            .WithName("HealthLive")
            .WithTags("Health");

        app.MapGet("/", () => Results.Ok(new
            {
                Service = "CringeBank.Api",
                Environment = app.Environment.EnvironmentName,
                Version = Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "unknown"
            }))
            .WithName("Root")
            .WithTags("Meta");

        app.MapPost("/api/session/bootstrap", async (
            HttpContext httpContext,
            FirebaseUserProfileFactory profileFactory,
            IUserSynchronizationService synchronizationService,
            CancellationToken cancellationToken) =>
        {
            if (httpContext.User?.Identity?.IsAuthenticated != true)
            {
                return Results.Unauthorized();
            }

            if (httpContext.Items.TryGetValue(UserSynchronizationResultItemKey, out var value) && value is UserSynchronizationResult cachedResult)
            {
                return Results.Ok(ToSessionBootstrapResponse(cachedResult));
            }

            var profile = profileFactory.Create(httpContext.User);
            var result = await synchronizationService.SynchronizeAsync(profile, cancellationToken);
            httpContext.Items[UserSynchronizationResultItemKey] = result;

            return Results.Ok(ToSessionBootstrapResponse(result));
        })
        .RequireAuthorization()
        .WithName("SessionBootstrap")
        .WithTags("Session");
    }
}

public sealed class CringeBankDbContextHealthCheck : IHealthCheck
{
    private readonly IServiceScopeFactory _serviceScopeFactory;

    public CringeBankDbContextHealthCheck(IServiceScopeFactory serviceScopeFactory)
    {
        _serviceScopeFactory = serviceScopeFactory ?? throw new ArgumentNullException(nameof(serviceScopeFactory));
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await using var scope = _serviceScopeFactory.CreateAsyncScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<CringeBankDbContext>();

            var canConnect = await dbContext.Database.CanConnectAsync(cancellationToken);

            return canConnect
                ? HealthCheckResult.Healthy("Database connection succeeded.")
                : HealthCheckResult.Unhealthy("Database connection failed.");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Database connection check threw an exception.", ex);
        }
    }
}
