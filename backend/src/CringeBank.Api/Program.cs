namespace CringeBank.Api;

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Net;
using System.Reflection;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using System.Linq;
using System.IdentityModel.Tokens.Jwt;
using Claim = System.Security.Claims.Claim;
using ClaimsIdentity = System.Security.Claims.ClaimsIdentity;
using CringeBank.Application;
using CringeBank.Application.Admin;
using CringeBank.Application.Chats;
using CringeBank.Application.Feeds;
using CringeBank.Application.Users;
using CringeBank.Application.Wallet;
using CringeBank.Application.Users.Commands;
using CringeBank.Application.Users.Queries;
using CringeBank.Api.Admin;
using CringeBank.Api.Authentication;
using CringeBank.Api.Authorization;
using CringeBank.Api.Auth;
using CringeBank.Api.Chats;
using CringeBank.Api.Feeds;
using CringeBank.Api.Profiles;
using CringeBank.Api.Session;
using CringeBank.Api.Wallet;
using CringeBank.Api.Security;
using CringeBank.Api.HealthChecks;
using CringeBank.Infrastructure;
using CringeBank.Infrastructure.Persistence;
using CringeBank.Infrastructure.Persistence.Seeding;
using CringeBank.Domain.Auth.Enums;
using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Google.Apis.Auth.OAuth2;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using Serilog.Events;
using Serilog.Filters;
using Microsoft.OpenApi.Any;
using Microsoft.OpenApi.Models;
using System.Threading.RateLimiting;
using System.Text.Json;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

public sealed partial class Program
{
    private const string UserSynchronizationResultItemKey = "__cringebank_user_sync_result";
    private const int DefaultFeedPageSize = 20;
    private const int AuthenticatedUserRateLimit = 120;
    private const int AnonymousUserRateLimit = 60;
    private static readonly TimeSpan RateLimitWindow = TimeSpan.FromMinutes(1);
    private static readonly string[] ReadyDbTags = { "ready", "db" };
    private static readonly string[] ReadyFirebaseTags = { "ready", "firebase" };
    private static readonly JsonSerializerOptions HealthCheckJsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = false
    };

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
        var app = BuildWebApplication(args);
        InitializeDatabase(app);
        app.Run();
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
                .Enrich.FromLogContext()
                .WriteTo.Logger(cfg => cfg
                    .Filter.ByIncludingOnly(Matching.WithProperty("SecurityEvent", true))
                    .WriteTo.File(
                        path: "logs/security-log-.txt",
                        rollingInterval: RollingInterval.Day,
                        retainedFileCountLimit: 30,
                        restrictedToMinimumLevel: LogEventLevel.Information,
                        formatProvider: CultureInfo.InvariantCulture));

            var seqSection = context.Configuration.GetSection("Telemetry:Seq");
            var seqUrl = seqSection["Url"];

            if (!string.IsNullOrWhiteSpace(seqUrl))
            {
                var apiKey = seqSection["ApiKey"];
                var minimumLevelValue = seqSection["MinimumLevel"];
                var restrictedLevel = LogEventLevel.Information;

                if (!string.IsNullOrWhiteSpace(minimumLevelValue)
                    && Enum.TryParse(minimumLevelValue, ignoreCase: true, out LogEventLevel parsedLevel))
                {
                    restrictedLevel = parsedLevel;
                }

                loggerConfiguration.WriteTo.Seq(
                    serverUrl: seqUrl,
                    apiKey: string.IsNullOrWhiteSpace(apiKey) ? null : apiKey,
                    restrictedToMinimumLevel: restrictedLevel);
            }
        });
    }

    private static void ConfigureServices(WebApplicationBuilder builder)
    {
        var services = builder.Services;
        var configuration = builder.Configuration;

    ConfigureTracing(builder, services, configuration);

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

        services.AddApplicationCore();
        services.AddInfrastructure(configuration);

        services.AddScoped<IDatabaseInitializer, DatabaseInitializer>();
        services.AddScoped<IDataSeeder, AuthRoleDataSeeder>();

        services.AddEndpointsApiExplorer();
        services.AddSwaggerGen();
        services.AddHealthChecks()
            .AddCheck<CringeBankDbContextHealthCheck>("database", tags: ReadyDbTags)
            .AddCheck<FirebaseAuthHealthCheck>("firebase_auth", tags: ReadyFirebaseTags)
            .AddCheck<AppCheckHealthCheck>("firebase_app_check", tags: ReadyFirebaseTags);
        services.AddSignalR();

        services.Configure<AppCheckOptions>(configuration.GetSection("Authentication:AppCheck"));
        services.AddSingleton<IAppCheckTokenVerifier, FirebaseAppCheckTokenVerifier>();
        services.AddHttpClient(FirebaseAppCheckTokenVerifier.HttpClientName, client =>
        {
            client.Timeout = TimeSpan.FromSeconds(10);
        });

        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(httpContext =>
            {
                var userId = GetUserPublicId(httpContext.User);

                if (userId.HasValue)
                {
                    var key = $"user:{userId.Value}";
                    return RateLimitPartition.GetTokenBucketLimiter(key, _ => new TokenBucketRateLimiterOptions
                    {
                        TokenLimit = AuthenticatedUserRateLimit,
                        TokensPerPeriod = AuthenticatedUserRateLimit,
                        ReplenishmentPeriod = RateLimitWindow,
                        QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                        QueueLimit = 0,
                        AutoReplenishment = true
                    });
                }

                var ipAddress = GetClientIpAddress(httpContext);
                var partitionKey = $"ip:{ipAddress}";

                return RateLimitPartition.GetTokenBucketLimiter(partitionKey, _ => new TokenBucketRateLimiterOptions
                {
                    TokenLimit = AnonymousUserRateLimit,
                    TokensPerPeriod = AnonymousUserRateLimit,
                    ReplenishmentPeriod = RateLimitWindow,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                    QueueLimit = 0,
                    AutoReplenishment = true
                });
            });

            options.OnRejected = (context, cancellationToken) =>
            {
                var retryAfterSeconds = (int)Math.Ceiling(RateLimitWindow.TotalSeconds);

                if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
                {
                    retryAfterSeconds = (int)Math.Ceiling(retryAfter.TotalSeconds);
                }

                context.HttpContext.Response.Headers.RetryAfter = retryAfterSeconds.ToString(CultureInfo.InvariantCulture);
                return ValueTask.CompletedTask;
            };
        });

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
        services.AddScoped<IChatEventPublisher, SignalRChatEventPublisher>();

        ConfigureAuthentication(services, configuration);
    }

    private static void InitializeDatabase(WebApplication app)
    {
        ArgumentNullException.ThrowIfNull(app);

        using var scope = app.Services.CreateScope();
        var initializer = scope.ServiceProvider.GetRequiredService<IDatabaseInitializer>();
        initializer.InitializeAsync().GetAwaiter().GetResult();
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
                        var dispatcher = context.HttpContext.RequestServices.GetRequiredService<IDispatcher>();

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
                            var command = new SynchronizeFirebaseUserCommand(profile);
                            var syncResult = await dispatcher.SendAsync<SynchronizeFirebaseUserCommand, UserSynchronizationResult>(command, context.HttpContext.RequestAborted);
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

    private static int NormalizePageSize(int? requested)
    {
        var value = requested.GetValueOrDefault(DefaultFeedPageSize);
        return Math.Clamp(value, 1, 100);
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
    app.UseRateLimiter();
        app.UseAuthorization();

        var swaggerEnabled = app.Configuration.GetValue<bool?>("Swagger:Enabled") ?? app.Environment.IsDevelopment();
        if (swaggerEnabled)
        {
            app.UseSwagger();
            app.UseSwaggerUI();
        }

        app.MapHealthChecks("/health/ready", new HealthCheckOptions
        {
            Predicate = healthCheck => healthCheck.Tags.Contains("ready", StringComparer.OrdinalIgnoreCase),
            ResponseWriter = WriteHealthCheckResponseAsync
        });
        app.MapGet("/health/live", () => Results.Ok(new { status = "Healthy" }))
            .WithSummary("Canlılık kontrolü")
            .WithDescription("Servisin ayakta olduğunu gösteren basit bir canlılık ping'i döndürür.")
            .Produces(StatusCodes.Status200OK)
            .WithName("HealthLive")
            .WithTags("Health");

        app.MapAuthEndpoints();

        var feedGroup = app.MapGroup("/api/feed")
            .RequireAuthorization()
            .RequireAppCheck()
            .WithTags("Feed");

        feedGroup.MapGet("/timeline", async (
            ClaimsPrincipal principal,
            int? pageSize,
            string? cursor,
            IDispatcher dispatcher,
            CancellationToken cancellationToken) =>
        {
            var viewerPublicId = GetUserPublicId(principal);

            if (viewerPublicId is null)
            {
                return Results.Unauthorized();
            }

            var size = NormalizePageSize(pageSize);
            var query = new FeedTimelineQuery(viewerPublicId.Value, size, cursor);
            var page = await dispatcher.QueryAsync<FeedTimelineQuery, FeedCursorPage<FeedItemResult>>(query, cancellationToken);

            return Results.Ok(FeedResponseMapper.Map(page));
        })
        .WithSummary("Zaman akışı öğelerini getirir")
        .WithDescription("Takip edilen kullanıcılar temel alınarak oturum sahibinin zaman akışı gönderilerini döndürür. Cursor tabanlı sayfalama destekler.")
        .Produces<FeedPageResponse<FeedItemResponse>>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status401Unauthorized)
        .Produces(StatusCodes.Status403Forbidden)
        .WithOpenApi(operation =>
        {
            SetQueryParameterDescription(operation, "pageSize", "Sayfa başına döndürülmesini istediğiniz gönderi sayısı (varsayılan 20, en fazla 100).");
            SetQueryParameterDescription(operation, "cursor", "Bir önceki çağrıda dönen `nextCursor` değeri ile takip eden sonuçları elde edin.");
            SetResponseExample(operation, "200", "Başarılı yanıt", CreateFeedPageExample());
            return operation;
        })
        .RequirePolicy("session", "bootstrap")
        .WithName("FeedTimeline");

        feedGroup.MapGet("/users/{publicId:guid}", async (
            Guid publicId,
            ClaimsPrincipal principal,
            int? pageSize,
            string? cursor,
            IDispatcher dispatcher,
            CancellationToken cancellationToken) =>
        {
            var viewerPublicId = GetUserPublicId(principal);

            if (viewerPublicId is null)
            {
                return Results.Unauthorized();
            }

            var profile = await dispatcher.QueryAsync<GetAuthUserProfileQuery, UserProfileResult?>(new GetAuthUserProfileQuery(publicId), cancellationToken);

            if (profile is null)
            {
                return Results.NotFound();
            }

            var size = NormalizePageSize(pageSize);
            var query = new FeedUserQuery(viewerPublicId.Value, publicId, size, cursor);
            var page = await dispatcher.QueryAsync<FeedUserQuery, FeedCursorPage<FeedItemResult>>(query, cancellationToken);

            return Results.Ok(FeedResponseMapper.Map(page));
        })
        .WithSummary("Belirli kullanıcının gönderilerini getirir")
        .WithDescription("Verilen kullanıcıya ait gönderileri oturum sahibinin erişim yetkisine göre döndürür.")
        .Produces<FeedPageResponse<FeedItemResponse>>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status401Unauthorized)
        .Produces(StatusCodes.Status403Forbidden)
        .Produces(StatusCodes.Status404NotFound)
        .WithOpenApi(operation =>
        {
            SetPathParameterDescription(operation, "publicId", "Gönderilerini listelemek istediğiniz kullanıcının genel kimliği.");
            SetQueryParameterDescription(operation, "pageSize", "Sayfa başına gönderi sayısı (varsayılan 20, en fazla 100).");
            SetQueryParameterDescription(operation, "cursor", "Bir önceki isteğin `nextCursor` değeri.");
            SetResponseExample(operation, "200", "Başarılı yanıt", CreateFeedPageExample());
            return operation;
        })
        .RequirePolicy("session", "bootstrap")
        .WithName("FeedUserTimeline");

        feedGroup.MapGet("/search", async (
            ClaimsPrincipal principal,
            string? term,
            int? pageSize,
            string? cursor,
            IDispatcher dispatcher,
            CancellationToken cancellationToken) =>
        {
            var viewerPublicId = GetUserPublicId(principal);

            if (viewerPublicId is null)
            {
                return Results.Unauthorized();
            }

            if (string.IsNullOrWhiteSpace(term))
            {
                return Results.BadRequest(new { error = "term_required" });
            }

            var size = NormalizePageSize(pageSize);
            var query = new FeedSearchQuery(viewerPublicId.Value, term, size, cursor);
            var page = await dispatcher.QueryAsync<FeedSearchQuery, FeedCursorPage<FeedItemResult>>(query, cancellationToken);

            return Results.Ok(FeedResponseMapper.Map(page));
        })
        .WithSummary("Feed gönderilerinde arama yapar")
        .WithDescription("Metin tabanlı arama ifadesini kullanarak erişilebilir gönderileri listeler.")
        .Produces<FeedPageResponse<FeedItemResponse>>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status400BadRequest)
        .Produces(StatusCodes.Status401Unauthorized)
        .Produces(StatusCodes.Status403Forbidden)
        .WithOpenApi(operation =>
        {
            SetQueryParameterDescription(operation, "term", "Aramak istediğiniz metin ifadesi (zorunlu).");
            SetQueryParameterDescription(operation, "pageSize", "Sayfa başına dönen sonuç sayısı (varsayılan 20, en fazla 100).");
            SetQueryParameterDescription(operation, "cursor", "Sonraki sonuçlar için cursor değeri.");
            SetResponseExample(operation, "200", "Başarılı yanıt", CreateFeedPageExample());
            SetResponseExample(operation, "400", "Geçersiz istek", CreateErrorResponseExample("term_required"));
            return operation;
        })
        .RequirePolicy("session", "bootstrap")
        .WithName("FeedSearch");

        var chatGroup = app.MapGroup("/api/chat")
            .RequireAuthorization()
            .RequireAppCheck()
            .WithTags("Chat");

        chatGroup.MapPost("/conversations", HandleCreateConversationAsync)
        .WithSummary("Yeni sohbet oluşturur")
        .WithDescription("Oturum sahibinin birebir veya grup sohbeti başlatmasına izin verir.")
        .Accepts<CreateConversationRequest>("application/json")
        .Produces<ConversationResponse>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status400BadRequest)
        .Produces(StatusCodes.Status401Unauthorized)
        .Produces(StatusCodes.Status403Forbidden)
        .WithOpenApi(operation =>
        {
            SetRequestExample(operation, CreateConversationRequestExample());
            SetResponseExample(operation, "200", "Başarılı yanıt", CreateConversationResponseExample());
            SetResponseExample(operation, "400", "Geçersiz istek", CreateErrorResponseExample("participants_invalid"));
            return operation;
        })
        .RequirePolicy("chat", "write")
        .WithName("ChatCreateConversation");

        chatGroup.MapPost("/conversations/{conversationId:guid}/messages", HandleSendMessageAsync)
        .WithSummary("Sohbete mesaj gönderir")
        .WithDescription("Belirtilen sohbete yeni bir metin mesajı ekler.")
        .Accepts<SendMessageRequest>("application/json")
        .Produces<MessageResponse>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status400BadRequest)
        .Produces(StatusCodes.Status401Unauthorized)
        .Produces(StatusCodes.Status403Forbidden)
        .Produces(StatusCodes.Status404NotFound)
        .WithOpenApi(operation =>
        {
            SetPathParameterDescription(operation, "conversationId", "Mesaj göndermek istediğiniz sohbetin genel kimliği.");
            SetRequestExample(operation, CreateSendMessageRequestExample());
            SetResponseExample(operation, "200", "Başarılı yanıt", CreateMessageResponseExample());
            SetResponseExample(operation, "400", "Geçersiz istek", CreateErrorResponseExample("invalid_body"));
            SetResponseExample(operation, "404", "Sohbet bulunamadı", CreateErrorResponseExample("conversation_not_found"));
            return operation;
        })
        .RequirePolicy("chat", "write")
        .WithName("ChatSendMessage");

        chatGroup.MapPost("/conversations/{conversationId:guid}/read", HandleMarkConversationReadAsync)
        .WithSummary("Sohbeti okunmuş olarak işaretler")
        .WithDescription("Kullanıcının belirtilen sohbette okuduğu son mesajı günceller.")
        .Accepts<MarkConversationReadRequest>("application/json")
        .Produces<ConversationReadResponse>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status400BadRequest)
        .Produces(StatusCodes.Status401Unauthorized)
        .Produces(StatusCodes.Status403Forbidden)
        .Produces(StatusCodes.Status404NotFound)
        .WithOpenApi(operation =>
        {
            SetPathParameterDescription(operation, "conversationId", "Okunmuş durumunu güncellemek istediğiniz sohbetin genel kimliği.");
            SetRequestExample(operation, CreateMarkConversationReadRequestExample());
            SetResponseExample(operation, "200", "Başarılı yanıt", CreateConversationReadResponseExample());
            SetResponseExample(operation, "400", "Geçersiz istek", CreateErrorResponseExample("message_id_invalid"));
            SetResponseExample(operation, "404", "Kaynak bulunamadı", CreateErrorResponseExample("message_not_found"));
            return operation;
        })
        .RequirePolicy("chat", "write")
        .WithName("ChatMarkRead");

        var walletGroup = app.MapGroup("/api/wallet")
            .RequireAuthorization()
            .RequireAppCheck()
            .WithTags("Wallet");

        walletGroup.MapGet("/balance", HandleGetWalletBalanceAsync)
            .WithSummary("Cüzdan bakiyesini getirir")
            .WithDescription("Oturum sahibinin cüzdan bakiyesi ve para birimini döndürür.")
            .Produces<WalletBalanceResponse>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .WithOpenApi(operation =>
            {
                SetResponseExample(operation, "200", "Başarılı yanıt", CreateWalletBalanceResponseExample());
                return operation;
            })
            .RequirePolicy("wallet", "read")
            .WithName("WalletGetBalance");

        walletGroup.MapGet("/transactions", HandleGetWalletTransactionsAsync)
            .WithSummary("Cüzdan hareketlerini listeler")
            .WithDescription("Cursor tabanlı sayfalama ile cüzdan işlem geçmişini döndürür.")
            .Produces<WalletTransactionsResponse>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .WithOpenApi(operation =>
            {
                SetQueryParameterDescription(operation, "pageSize", "Sayfa başına dönecek işlem sayısı (varsayılan 20, en fazla 100).");
                SetQueryParameterDescription(operation, "cursor", "Sonraki sayfayı almak için kullanılacak cursor değeri.");
                SetResponseExample(operation, "200", "Başarılı yanıt", CreateWalletTransactionsResponseExample());
                return operation;
            })
            .RequirePolicy("wallet", "read")
            .WithName("WalletGetTransactions");

        walletGroup.MapPost("/orders/{orderId:guid}/release", HandleReleaseEscrowAsync)
            .WithSummary("Escrow ödemesini serbest bırakır")
            .WithDescription("Escrow bakiyesini satıcıya aktarmak için kullanılır.")
            .Accepts<ReleaseEscrowRequest>("application/json")
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status409Conflict)
            .WithOpenApi(operation =>
            {
                SetPathParameterDescription(operation, "orderId", "Escrow işleminin ilişkili olduğu sipariş kimliği.");
                SetRequestExample(operation, CreateReleaseEscrowRequestExample(), required: false);
                SetResponseExample(operation, "200", "Başarılı yanıt", CreateSuccessResponseExample());
                SetResponseExample(operation, "404", "Kaynak bulunamadı", CreateErrorResponseExample("order_not_found"));
                SetResponseExample(operation, "409", "İşlem durumu uygun değil", CreateErrorResponseExample("invalid_order_status"));
                return operation;
            })
            .RequirePolicy("wallet", "write")
            .WithName("WalletReleaseEscrow");

        walletGroup.MapPost("/orders/{orderId:guid}/refund", HandleRefundEscrowAsync)
            .WithSummary("Escrow ödemesini iade eder")
            .WithDescription("Escrow bakiyesini alıcıya iade etmek için kullanılır.")
            .Accepts<RefundEscrowRequest>("application/json")
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status409Conflict)
            .WithOpenApi(operation =>
            {
                SetPathParameterDescription(operation, "orderId", "İade işleminin hedeflediği sipariş kimliği.");
                SetRequestExample(operation, CreateRefundEscrowRequestExample(), required: false);
                SetResponseExample(operation, "200", "Başarılı yanıt", CreateSuccessResponseExample());
                SetResponseExample(operation, "404", "Kaynak bulunamadı", CreateErrorResponseExample("order_not_found"));
                SetResponseExample(operation, "409", "İşlem durumu uygun değil", CreateErrorResponseExample("invalid_order_status"));
                return operation;
            })
            .RequirePolicy("wallet", "write")
            .WithName("WalletRefundEscrow");

        var adminUsersGroup = app.MapGroup("/api/admin/users")
            .RequireAuthorization()
            .RequireAppCheck()
            .WithTags("Admin");

        adminUsersGroup.MapGet("/", HandleGetAdminUsersAsync)
            .WithSummary("Admin kullanıcılarını listeler")
            .WithDescription("Rol, durum ve arama filtresi ile admin panosunda kullanıcıları listeler.")
            .Produces<AdminUserPageResponse>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .WithOpenApi(operation =>
            {
                SetQueryParameterDescription(operation, "term", "E-posta, kullanıcı adı veya görünen ad için arama ifadesi.");
                SetQueryParameterDescription(operation, "status", "Filtrelemek istediğiniz kullanıcı durumu (Active, Suspended, Banned vb.).");
                SetQueryParameterDescription(operation, "role", "Belirli bir rol adına göre filtreleme yapar.");
                SetQueryParameterDescription(operation, "pageSize", "Sayfa başına kullanıcı sayısı (varsayılan 25, en fazla 100).");
                SetQueryParameterDescription(operation, "cursor", "Sonraki kullanıcıları almak için cursor değeri.");
                SetResponseExample(operation, "200", "Başarılı yanıt", CreateAdminUserPageExample());
                SetResponseExample(operation, "400", "Geçersiz istek", CreateErrorResponseExample("status_invalid"));
                return operation;
            })
            .RequirePolicy("admin", "read")
            .WithName("AdminUsersList");

        adminUsersGroup.MapPost("/{userId:guid}/roles", HandleAssignUserRoleAsync)
            .WithSummary("Kullanıcıya rol atar")
            .WithDescription("Belirtilen kullanıcıya yeni bir rol ekler.")
            .Accepts<AssignRoleRequest>("application/json")
            .Produces<AdminUserResponse>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status409Conflict)
            .WithOpenApi(operation =>
            {
                SetPathParameterDescription(operation, "userId", "Rol atanacak kullanıcının genel kimliği.");
                SetRequestExample(operation, CreateAssignRoleRequestExample());
                SetResponseExample(operation, "200", "Başarılı yanıt", CreateAdminUserResponseExample());
                SetResponseExample(operation, "400", "Geçersiz istek", CreateErrorResponseExample("role_required"));
                SetResponseExample(operation, "404", "Kullanıcı bulunamadı", CreateErrorResponseExample("user_not_found"));
                SetResponseExample(operation, "409", "Rol zaten atanmış", CreateErrorResponseExample("role_already_assigned"));
                return operation;
            })
            .RequirePolicy("admin", "write")
            .WithName("AdminUsersAssignRole");

        adminUsersGroup.MapDelete("/{userId:guid}/roles/{roleName}", HandleRemoveUserRoleAsync)
            .WithSummary("Kullanıcıdan rol kaldırır")
            .WithDescription("Belirtilen rolü kullanıcının yetkilerinden siler.")
            .Produces<AdminUserResponse>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status409Conflict)
            .WithOpenApi(operation =>
            {
                SetPathParameterDescription(operation, "userId", "Rolü kaldırılacak kullanıcının genel kimliği.");
                SetPathParameterDescription(operation, "roleName", "Kaldırılacak rol adı.");
                SetResponseExample(operation, "200", "Başarılı yanıt", CreateAdminUserResponseExample());
                SetResponseExample(operation, "400", "Geçersiz istek", CreateErrorResponseExample("role_required"));
                SetResponseExample(operation, "404", "Kullanıcı veya rol bulunamadı", CreateErrorResponseExample("role_not_found"));
                SetResponseExample(operation, "409", "Rol ilişkisi bulunmuyor", CreateErrorResponseExample("role_not_assigned"));
                return operation;
            })
            .RequirePolicy("admin", "write")
            .WithName("AdminUsersRemoveRole");

        adminUsersGroup.MapPost("/{userId:guid}/status", HandleUpdateUserStatusAsync)
            .WithSummary("Kullanıcı durumunu günceller")
            .WithDescription("Kullanıcının Active, Suspended veya Banned gibi durumlarını değiştirir.")
            .Accepts<UpdateUserStatusRequest>("application/json")
            .Produces(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status409Conflict)
            .WithOpenApi(operation =>
            {
                SetPathParameterDescription(operation, "userId", "Durumu güncellenecek kullanıcının genel kimliği.");
                SetRequestExample(operation, CreateUpdateUserStatusRequestExample());
                SetResponseExample(operation, "200", "Başarılı yanıt", CreateAdminStatusUpdateResponseExample());
                SetResponseExample(operation, "400", "Geçersiz istek", CreateErrorResponseExample("status_invalid"));
                SetResponseExample(operation, "404", "Kullanıcı bulunamadı", CreateErrorResponseExample("user_not_found"));
                SetResponseExample(operation, "409", "Durum değişmedi", CreateErrorResponseExample("status_unchanged"));
                return operation;
            })
            .RequirePolicy("admin", "write")
            .WithName("AdminUsersUpdateStatus");

        app.MapGet("/", () => Results.Ok(new
            {
                Service = "CringeBank.Api",
                Environment = app.Environment.EnvironmentName,
                Version = Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "unknown"
            }))
            .WithSummary("Servis durumunu döndürür")
            .WithDescription("API servis adını, ortam bilgisini ve sürüm numarasını bildirir.")
            .Produces(StatusCodes.Status200OK)
            .WithOpenApi(operation =>
            {
                SetResponseExample(operation, "200", "Başarılı yanıt", CreateRootResponseExample());
                return operation;
            })
            .WithName("Root")
            .WithTags("Meta");

        app.MapGet("/api/profiles/{publicId:guid}", async (
            Guid publicId,
            IUserReadRepository repository,
            CancellationToken cancellationToken) =>
        {
            var profile = await repository.GetProfileByPublicIdAsync(publicId, cancellationToken);

            if (profile is null)
            {
                return Results.NotFound();
            }

            return Results.Ok(PublicProfileMapper.Map(profile));
        })
        .WithSummary("Genel profili getirir")
        .WithDescription("Belirtilen kullanıcının herkese açık profil bilgilerini döndürür.")
        .Produces<PublicProfileResponse>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status404NotFound)
        .WithOpenApi(operation =>
        {
            SetPathParameterDescription(operation, "publicId", "Profil bilgilerini görüntülemek istediğiniz kullanıcının genel kimliği.");
            SetResponseExample(operation, "200", "Başarılı yanıt", CreatePublicProfileResponseExample());
            return operation;
        })
        .WithName("ProfilesGetByPublicId")
        .WithTags("Profiles");

        app.MapGet("/api/profiles/me", async (
            ClaimsPrincipal principal,
            IDispatcher dispatcher,
            CancellationToken cancellationToken) =>
        {
            var publicId = GetUserPublicId(principal);

            if (publicId is null)
            {
                return Results.Unauthorized();
            }

            var query = new GetAuthUserProfileQuery(publicId.Value);
            var profile = await dispatcher.QueryAsync<GetAuthUserProfileQuery, UserProfileResult?>(query, cancellationToken);

            if (profile is null)
            {
                return Results.NotFound();
            }

            return Results.Ok(SelfProfileMapper.Map(profile));
        })
    .RequireAuthorization()
    .RequireAppCheck()
        .WithSummary("Kendi profilini getirir")
        .WithDescription("Oturum sahibinin detaylı profil bilgilerini döndürür.")
        .Produces<SelfProfileResponse>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status401Unauthorized)
        .Produces(StatusCodes.Status404NotFound)
        .WithOpenApi(operation =>
        {
            SetResponseExample(operation, "200", "Başarılı yanıt", CreateSelfProfileResponseExample());
            SetResponseExample(operation, "404", "Profil bulunamadı", CreateErrorResponseExample("user_not_found"));
            return operation;
        })
        .RequirePolicy("session", "bootstrap")
        .WithName("ProfilesGetSelf")
        .WithTags("Profiles");

        app.MapPut("/api/profiles/me", async (
            ClaimsPrincipal principal,
            UpdateAuthUserProfileRequest request,
            IDispatcher dispatcher,
            CancellationToken cancellationToken) =>
        {
            var publicId = GetUserPublicId(principal);

            if (publicId is null)
            {
                return Results.Unauthorized();
            }

            if (request is null)
            {
                return Results.BadRequest(new { error = "invalid_payload" });
            }

            var command = new UpdateAuthUserProfileCommand(
                publicId.Value,
                request.DisplayName,
                request.Bio,
                request.Website,
                request.AvatarUrl,
                request.BannerUrl,
                request.Location);

            var result = await dispatcher.SendAsync<UpdateAuthUserProfileCommand, UpdateAuthUserProfileResult>(command, cancellationToken);

            if (!result.Success || result.Profile is null)
            {
                return MapUpdateProfileFailure(result);
            }

            return Results.Ok(SelfProfileMapper.Map(result.Profile));
        })
    .RequireAuthorization()
    .RequireAppCheck()
        .WithSummary("Kendi profilini günceller")
        .WithDescription("Oturum sahibinin profil bilgilerini (görünen ad, bio, site vb.) günceller.")
        .Accepts<UpdateAuthUserProfileRequest>("application/json")
        .Produces<SelfProfileResponse>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status400BadRequest)
        .Produces(StatusCodes.Status401Unauthorized)
        .Produces(StatusCodes.Status403Forbidden)
        .Produces(StatusCodes.Status404NotFound)
        .WithOpenApi(operation =>
        {
            SetRequestExample(operation, CreateUpdateProfileRequestExample());
            SetResponseExample(operation, "200", "Başarılı yanıt", CreateSelfProfileResponseExample());
            SetResponseExample(operation, "400", "Geçersiz istek", CreateErrorResponseExample("invalid_payload"));
            SetResponseExample(operation, "404", "Profil bulunamadı", CreateErrorResponseExample("user_not_found"));
            return operation;
        })
        .RequirePolicy("session", "bootstrap")
        .WithName("ProfilesUpdateSelf")
        .WithTags("Profiles");

        app.MapPost("/api/profiles/me/uploads", async (
            ClaimsPrincipal principal,
            GenerateProfileMediaUploadUrlRequest request,
            IDispatcher dispatcher,
            CancellationToken cancellationToken) =>
        {
            var publicId = GetUserPublicId(principal);

            if (publicId is null)
            {
                return Results.Unauthorized();
            }

            if (request is null)
            {
                return Results.BadRequest(new { error = "invalid_payload" });
            }

            var mediaTypeValue = request.MediaType?.Trim();

            if (string.IsNullOrWhiteSpace(mediaTypeValue) || !Enum.TryParse<ProfileMediaType>(mediaTypeValue, ignoreCase: true, out var mediaType))
            {
                return Results.BadRequest(new { error = "unsupported_media_type" });
            }

            var contentType = request.ContentType?.Trim() ?? string.Empty;

            var command = new GenerateProfileMediaUploadUrlCommand(publicId.Value, mediaType, contentType);
            var result = await dispatcher.SendAsync<GenerateProfileMediaUploadUrlCommand, GenerateProfileMediaUploadUrlResult>(command, cancellationToken);

            if (!result.Success || result.Token is null)
            {
                return MapUploadTokenFailure(result);
            }

            var response = new ProfileMediaUploadResponse(
                result.Token.UploadUri,
                result.Token.ResourceUri,
                result.Token.ExpiresAtUtc,
                result.Token.BlobName,
                result.Token.ContentType);

            return Results.Ok(response);
        })
    .RequireAuthorization()
    .RequireAppCheck()
        .WithSummary("Profil medyası yükleme adresi oluşturur")
        .WithDescription("Avatar veya banner için imzalı yükleme URL'si üretir.")
        .Accepts<GenerateProfileMediaUploadUrlRequest>("application/json")
        .Produces<ProfileMediaUploadResponse>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status400BadRequest)
        .Produces(StatusCodes.Status401Unauthorized)
        .Produces(StatusCodes.Status403Forbidden)
        .Produces(StatusCodes.Status503ServiceUnavailable)
        .WithOpenApi(operation =>
        {
            SetRequestExample(operation, CreateProfileMediaUploadRequestExample());
            SetResponseExample(operation, "200", "Başarılı yanıt", CreateProfileMediaUploadResponseExample());
            SetResponseExample(operation, "400", "Geçersiz istek", CreateErrorResponseExample("unsupported_media_type"));
            SetResponseExample(operation, "503", "Depolama yapılandırılmadı", CreateErrorResponseExample("storage_not_configured"));
            return operation;
        })
        .RequirePolicy("session", "bootstrap")
        .WithName("ProfilesCreateUploadToken")
        .WithTags("Profiles");

        app.MapPost("/api/session/bootstrap", async (
            HttpContext httpContext,
            FirebaseUserProfileFactory profileFactory,
            IDispatcher dispatcher,
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
            var command = new SynchronizeFirebaseUserCommand(profile);
            var result = await dispatcher.SendAsync<SynchronizeFirebaseUserCommand, UserSynchronizationResult>(command, cancellationToken);
            httpContext.Items[UserSynchronizationResultItemKey] = result;

            return Results.Ok(ToSessionBootstrapResponse(result));
    })
    .RequireAuthorization()
    .RequireAppCheck()
    .WithSummary("Oturum başlatma verilerini döndürür")
    .WithDescription("Kimliği doğrulanmış kullanıcı için profil ve oturum özetini döndürerek istemcinin oturum açılışını tamamlar.")
    .Produces<SessionBootstrapResponse>(StatusCodes.Status200OK)
    .Produces(StatusCodes.Status401Unauthorized)
    .WithOpenApi(operation =>
    {
        SetResponseExample(operation, "200", "Başarılı yanıt", CreateSessionBootstrapResponseExample());
        return operation;
    })
    .RequirePolicy("session", "bootstrap")
        .WithName("SessionBootstrap")
        .WithTags("Session");

        app.MapHub<ChatHub>("/hubs/chat");
    }

    private static Task WriteHealthCheckResponseAsync(HttpContext context, HealthReport report)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(report);

        context.Response.ContentType = "application/json";

        var payload = new
        {
            status = report.Status.ToString(),
            totalDurationMs = report.TotalDuration.TotalMilliseconds,
            results = report.Entries.Select(entry => new
            {
                name = entry.Key,
                status = entry.Value.Status.ToString(),
                durationMs = entry.Value.Duration.TotalMilliseconds,
                description = entry.Value.Description,
                error = entry.Value.Exception?.Message
            })
        };

        var json = JsonSerializer.Serialize(payload, HealthCheckJsonOptions);
        return context.Response.WriteAsync(json);
    }

    private static void ConfigureTracing(WebApplicationBuilder builder, IServiceCollection services, ConfigurationManager configuration)
    {
        ArgumentNullException.ThrowIfNull(builder);
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(configuration);

        var tracingSection = configuration.GetSection("Telemetry:Tracing");
        var enabled = tracingSection.GetValue<bool?>("Enabled") ?? true;

        if (!enabled)
        {
            return;
        }

        var serviceName = tracingSection["ServiceName"];
        if (string.IsNullOrWhiteSpace(serviceName))
        {
            serviceName = builder.Environment.ApplicationName ?? "CringeBank.Api";
        }

        var serviceNamespace = tracingSection["ServiceNamespace"];
        if (string.IsNullOrWhiteSpace(serviceNamespace))
        {
            serviceNamespace = null;
        }

        var serviceVersion = tracingSection["ServiceVersion"];
        if (string.IsNullOrWhiteSpace(serviceVersion))
        {
            serviceVersion = Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "1.0.0";
        }

        var serviceInstanceId = tracingSection["ServiceInstanceId"];
        if (string.IsNullOrWhiteSpace(serviceInstanceId))
        {
            serviceInstanceId = Environment.MachineName;
        }

        services.AddOpenTelemetry()
            .WithTracing(tracing =>
            {
                tracing
                    .SetResourceBuilder(CreateServiceResource(serviceName, serviceNamespace, serviceVersion, serviceInstanceId, builder.Environment.EnvironmentName))
                    .AddAspNetCoreInstrumentation(options =>
                    {
                        options.RecordException = true;
                        options.Filter = httpContext => !httpContext.Request.Path.StartsWithSegments("/health", StringComparison.OrdinalIgnoreCase);
                    })
                    .AddHttpClientInstrumentation(options =>
                    {
                        options.RecordException = true;
                    })
                    .AddSource("CringeBank.Application");

                var additionalSources = tracingSection.GetSection("Sources").Get<string[]>();
                if (additionalSources is { Length: > 0 })
                {
                    foreach (var source in additionalSources)
                    {
                        if (!string.IsNullOrWhiteSpace(source))
                        {
                            tracing.AddSource(source);
                        }
                    }
                }

                ConfigureTracingExporter(tracing, tracingSection);
            });
    }

    private static ResourceBuilder CreateServiceResource(string serviceName, string? serviceNamespace, string serviceVersion, string serviceInstanceId, string environmentName)
    {
        var resourceBuilder = ResourceBuilder.CreateDefault()
            .AddService(serviceName, serviceNamespace: serviceNamespace, serviceVersion: serviceVersion);

        resourceBuilder = resourceBuilder.AddAttributes(new[]
        {
            new KeyValuePair<string, object>("service.instance.id", serviceInstanceId),
            new KeyValuePair<string, object>("deployment.environment", environmentName)
        });

        return resourceBuilder;
    }

    private static void ConfigureTracingExporter(TracerProviderBuilder tracing, IConfigurationSection tracingSection)
    {
        ArgumentNullException.ThrowIfNull(tracing);
        ArgumentNullException.ThrowIfNull(tracingSection);

        var exporter = tracingSection["Exporter"];

        if (string.Equals(exporter, "otlp", StringComparison.OrdinalIgnoreCase))
        {
            tracing.AddOtlpExporter(options =>
            {
                var endpoint = tracingSection["OtlpEndpoint"];
                if (!string.IsNullOrWhiteSpace(endpoint) && Uri.TryCreate(endpoint, UriKind.Absolute, out var uri))
                {
                    options.Endpoint = uri;
                }

                var headers = tracingSection.GetSection("OtlpHeaders").Get<string[]>();
                if (headers is { Length: > 0 })
                {
                    var normalized = headers
                        .Select(header => header?.Trim())
                        .Where(header => !string.IsNullOrWhiteSpace(header))
                        .Select(header => header!)
                        .ToArray();

                    if (normalized.Length > 0)
                    {
                        options.Headers = string.Join(",", normalized);
                    }
                }
            });
        }
        else
        {
            tracing.AddConsoleExporter();
        }
    }

    private static Guid? GetUserPublicId(ClaimsPrincipal? principal)
    {
        if (principal is null)
        {
            return null;
        }

        var candidates = new[]
        {
            principal.FindFirstValue("uid"),
            principal.FindFirstValue("firebase_uid"),
            principal.FindFirstValue(ClaimTypes.NameIdentifier),
            principal.FindFirstValue(JwtRegisteredClaimNames.Sub)
        };

        foreach (var candidate in candidates)
        {
            if (!string.IsNullOrWhiteSpace(candidate) && Guid.TryParse(candidate, out var guid))
            {
                return guid;
            }
        }

        return null;
    }

    private static string GetClientIpAddress(HttpContext context)
    {
        ArgumentNullException.ThrowIfNull(context);

        if (context.Connection.RemoteIpAddress is IPAddress address)
        {
            if (address.IsIPv4MappedToIPv6)
            {
                address = address.MapToIPv4();
            }

            return address.ToString();
        }

        return "unknown";
    }

    private static void SetQueryParameterDescription(OpenApiOperation operation, string name, string description)
    {
        ArgumentNullException.ThrowIfNull(operation);
        ArgumentException.ThrowIfNullOrWhiteSpace(name);

        if (operation.Parameters is null || operation.Parameters.Count == 0)
        {
            return;
        }

        var parameter = operation.Parameters
            .FirstOrDefault(item => string.Equals(item.Name, name, StringComparison.OrdinalIgnoreCase));

        if (parameter is null)
        {
            return;
        }

        parameter.Description = description;
        parameter.In = ParameterLocation.Query;
    }

    private static void SetPathParameterDescription(OpenApiOperation operation, string name, string description)
    {
        ArgumentNullException.ThrowIfNull(operation);
        ArgumentException.ThrowIfNullOrWhiteSpace(name);

        if (operation.Parameters is null || operation.Parameters.Count == 0)
        {
            return;
        }

        var parameter = operation.Parameters
            .FirstOrDefault(item => string.Equals(item.Name, name, StringComparison.OrdinalIgnoreCase));

        if (parameter is null)
        {
            return;
        }

        parameter.Description = description;
        parameter.In = ParameterLocation.Path;
        parameter.Required = true;
    }

    private static void SetResponseExample(OpenApiOperation operation, string statusCode, string description, IOpenApiAny example)
    {
        ArgumentNullException.ThrowIfNull(operation);
        ArgumentNullException.ThrowIfNull(example);
        ArgumentException.ThrowIfNullOrWhiteSpace(statusCode);

        if (!operation.Responses.TryGetValue(statusCode, out var response))
        {
            response = new OpenApiResponse { Description = description };
            operation.Responses[statusCode] = response;
        }
        else if (string.IsNullOrWhiteSpace(response.Description))
        {
            response.Description = description;
        }

        response.Content ??= new Dictionary<string, OpenApiMediaType>(StringComparer.OrdinalIgnoreCase);

        if (!response.Content.TryGetValue("application/json", out var mediaType) || mediaType is null)
        {
            mediaType = new OpenApiMediaType();
            response.Content["application/json"] = mediaType;
        }

        mediaType.Example = example;
    }

    private static void SetRequestExample(OpenApiOperation operation, IOpenApiAny example, bool required = true)
    {
        ArgumentNullException.ThrowIfNull(operation);
        ArgumentNullException.ThrowIfNull(example);

        operation.RequestBody ??= new OpenApiRequestBody
        {
            Required = required,
            Content = new Dictionary<string, OpenApiMediaType>(StringComparer.OrdinalIgnoreCase)
        };

        if (!operation.RequestBody.Content.TryGetValue("application/json", out var mediaType) || mediaType is null)
        {
            mediaType = new OpenApiMediaType();
            operation.RequestBody.Content["application/json"] = mediaType;
        }

        mediaType.Example = example;
    }

    private static OpenApiObject CreateFeedPageExample()
    {
        return new OpenApiObject
        {
            ["items"] = new OpenApiArray
            {
                new OpenApiObject
                {
                    ["publicId"] = new OpenApiString("0f3a5c5c-8667-4fad-bb39-3ae1cb4fd3f1"),
                    ["authorPublicId"] = new OpenApiString("95c46c80-78c8-4a4d-a109-066782edc68a"),
                    ["authorUsername"] = new OpenApiString("cringemaster"),
                    ["authorDisplayName"] = new OpenApiString("Cringe Master"),
                    ["authorAvatarUrl"] = new OpenApiString("https://cdn.cringebank.app/avatars/cringemaster.png"),
                    ["text"] = new OpenApiString("Bugün markette gördüğüm indirim cidden cringe."),
                    ["visibility"] = new OpenApiString("Public"),
                    ["likesCount"] = new OpenApiInteger(128),
                    ["commentsCount"] = new OpenApiInteger(12),
                    ["savesCount"] = new OpenApiInteger(3),
                    ["createdAt"] = new OpenApiString("2025-10-21T09:15:00Z"),
                    ["updatedAt"] = new OpenApiString("2025-10-21T09:45:00Z"),
                    ["media"] = new OpenApiArray
                    {
                        new OpenApiObject
                        {
                            ["url"] = new OpenApiString("https://cdn.cringebank.app/media/post123-1.jpg"),
                            ["mime"] = new OpenApiString("image/jpeg"),
                            ["width"] = new OpenApiInteger(1080),
                            ["height"] = new OpenApiInteger(1920),
                            ["orderIndex"] = new OpenApiInteger(0)
                        }
                    }
                }
            },
            ["nextCursor"] = new OpenApiString("eyJwYWdlU2l6ZSI6MjB9"),
            ["hasMore"] = new OpenApiBoolean(true)
        };
    }

    private static OpenApiObject CreateErrorResponseExample(string code, string? message = null)
    {
        var obj = new OpenApiObject
        {
            ["error"] = new OpenApiString(code)
        };

        if (!string.IsNullOrWhiteSpace(message))
        {
            obj["message"] = new OpenApiString(message!);
        }

        return obj;
    }

    private static OpenApiObject CreateConversationRequestExample()
    {
        return new OpenApiObject
        {
            ["isGroup"] = new OpenApiBoolean(false),
            ["title"] = new OpenApiString("Özel sohbet"),
            ["participantPublicIds"] = new OpenApiArray
            {
                new OpenApiString("9c1f52aa-6f8c-4d3c-9eab-64143acb06d7"),
                new OpenApiString("53b4c7e0-0d8e-47e2-a1d5-1fb23bb36816")
            }
        };
    }

    private static OpenApiObject CreateConversationResponseExample()
    {
        return new OpenApiObject
        {
            ["publicId"] = new OpenApiString("c3f9e0ad-5db6-46ef-86b8-3c1c0f47edc2"),
            ["isGroup"] = new OpenApiBoolean(false),
            ["title"] = new OpenApiString("Özel sohbet"),
            ["createdAt"] = new OpenApiString("2025-10-21T08:00:00Z"),
            ["updatedAt"] = new OpenApiString("2025-10-21T08:05:00Z"),
            ["members"] = new OpenApiArray
            {
                new OpenApiObject
                {
                    ["userPublicId"] = new OpenApiString("9c1f52aa-6f8c-4d3c-9eab-64143acb06d7"),
                    ["role"] = new OpenApiString("Owner"),
                    ["joinedAt"] = new OpenApiString("2025-10-21T08:00:00Z"),
                    ["lastReadMessageId"] = new OpenApiLong(128),
                    ["lastReadAt"] = new OpenApiString("2025-10-21T08:04:30Z")
                },
                new OpenApiObject
                {
                    ["userPublicId"] = new OpenApiString("53b4c7e0-0d8e-47e2-a1d5-1fb23bb36816"),
                    ["role"] = new OpenApiString("Participant"),
                    ["joinedAt"] = new OpenApiString("2025-10-21T08:00:20Z"),
                    ["lastReadMessageId"] = new OpenApiLong(126),
                    ["lastReadAt"] = new OpenApiString("2025-10-21T08:03:10Z")
                }
            }
        };
    }

    private static OpenApiObject CreateSendMessageRequestExample()
    {
        return new OpenApiObject
        {
            ["body"] = new OpenApiString("Selam, durum nasıl?")
        };
    }

    private static OpenApiObject CreateMessageResponseExample()
    {
        return new OpenApiObject
        {
            ["id"] = new OpenApiLong(256),
            ["conversationPublicId"] = new OpenApiString("c3f9e0ad-5db6-46ef-86b8-3c1c0f47edc2"),
            ["senderPublicId"] = new OpenApiString("9c1f52aa-6f8c-4d3c-9eab-64143acb06d7"),
            ["body"] = new OpenApiString("Selam, durum nasıl?"),
            ["deletedForAll"] = new OpenApiBoolean(false),
            ["createdAt"] = new OpenApiString("2025-10-21T08:05:30Z"),
            ["editedAt"] = new OpenApiString("2025-10-21T08:06:00Z"),
            ["participantPublicIds"] = new OpenApiArray
            {
                new OpenApiString("9c1f52aa-6f8c-4d3c-9eab-64143acb06d7"),
                new OpenApiString("53b4c7e0-0d8e-47e2-a1d5-1fb23bb36816")
            }
        };
    }

    private static OpenApiObject CreateMarkConversationReadRequestExample()
    {
        return new OpenApiObject
        {
            ["messageId"] = new OpenApiLong(256)
        };
    }

    private static OpenApiObject CreateConversationReadResponseExample()
    {
        return new OpenApiObject
        {
            ["conversationPublicId"] = new OpenApiString("c3f9e0ad-5db6-46ef-86b8-3c1c0f47edc2"),
            ["userPublicId"] = new OpenApiString("9c1f52aa-6f8c-4d3c-9eab-64143acb06d7"),
            ["lastReadMessageId"] = new OpenApiLong(256),
            ["lastReadAt"] = new OpenApiString("2025-10-21T08:07:00Z"),
            ["participantPublicIds"] = new OpenApiArray
            {
                new OpenApiString("9c1f52aa-6f8c-4d3c-9eab-64143acb06d7"),
                new OpenApiString("53b4c7e0-0d8e-47e2-a1d5-1fb23bb36816")
            }
        };
    }

    private static OpenApiObject CreateWalletBalanceResponseExample()
    {
        return new OpenApiObject
        {
            ["balance"] = new OpenApiDouble(154.75),
            ["currency"] = new OpenApiString("TRY"),
            ["updatedAtUtc"] = new OpenApiString("2025-10-21T07:45:00Z")
        };
    }

    private static OpenApiObject CreateWalletTransactionsResponseExample()
    {
        return new OpenApiObject
        {
            ["items"] = new OpenApiArray
            {
                new OpenApiObject
                {
                    ["id"] = new OpenApiLong(4123),
                    ["type"] = new OpenApiString("EscrowReleased"),
                    ["amount"] = new OpenApiDouble(250.00),
                    ["balanceAfter"] = new OpenApiDouble(504.25),
                    ["reference"] = new OpenApiString("order_94d1"),
                    ["metadata"] = new OpenApiString("{\"orderId\":\"94d1\"}"),
                    ["createdAtUtc"] = new OpenApiString("2025-10-21T06:12:00Z")
                }
            },
            ["nextCursor"] = new OpenApiString("eyJpZCI6NDEyM30="),
            ["hasMore"] = new OpenApiBoolean(false)
        };
    }

    private static OpenApiObject CreateReleaseEscrowRequestExample()
    {
        return new OpenApiObject
        {
            ["isSystemOverride"] = new OpenApiBoolean(false)
        };
    }

    private static OpenApiObject CreateRefundEscrowRequestExample()
    {
        return new OpenApiObject
        {
            ["isSystemOverride"] = new OpenApiBoolean(true),
            ["refundReason"] = new OpenApiString("Alıcı onayıyla iade edildi")
        };
    }

    private static OpenApiObject CreateSuccessResponseExample()
    {
        return new OpenApiObject
        {
            ["success"] = new OpenApiBoolean(true)
        };
    }

    private static OpenApiObject CreateAdminUserResponseExample()
    {
        return new OpenApiObject
        {
            ["publicId"] = new OpenApiString("b2b79f49-1a0c-4f2e-bf73-0f2b7c40c0f1"),
            ["email"] = new OpenApiString("admin@cringebank.app"),
            ["username"] = new OpenApiString("admin"),
            ["status"] = new OpenApiString("Active"),
            ["createdAt"] = new OpenApiString("2025-01-05T10:00:00Z"),
            ["updatedAt"] = new OpenApiString("2025-10-20T14:30:00Z"),
            ["lastLoginAt"] = new OpenApiString("2025-10-21T07:15:00Z"),
            ["displayName"] = new OpenApiString("CringeBank Admin"),
            ["roles"] = new OpenApiArray
            {
                new OpenApiString("admin"),
                new OpenApiString("moderator")
            }
        };
    }

    private static OpenApiObject CreateAdminUserPageExample()
    {
        return new OpenApiObject
        {
            ["items"] = new OpenApiArray
            {
                CreateAdminUserResponseExample()
            },
            ["nextCursor"] = new OpenApiString("eyJwdWJsaWNJZCI6ImIyYjc5ZjQ5LTEwIn0="),
            ["hasMore"] = new OpenApiBoolean(false)
        };
    }

    private static OpenApiObject CreateAssignRoleRequestExample()
    {
        return new OpenApiObject
        {
            ["role"] = new OpenApiString("moderator")
        };
    }

    private static OpenApiObject CreateUpdateUserStatusRequestExample()
    {
        return new OpenApiObject
        {
            ["status"] = new OpenApiString("Suspended")
        };
    }

    private static OpenApiObject CreateAdminStatusUpdateResponseExample()
    {
        return new OpenApiObject
        {
            ["status"] = new OpenApiString("Suspended"),
            ["user"] = CreateAdminUserResponseExample()
        };
    }

    private static OpenApiObject CreatePublicProfileResponseExample()
    {
        return new OpenApiObject
        {
            ["publicId"] = new OpenApiString("5d5f7a0b-3f42-4c05-87d5-7815539d0ab7"),
            ["username"] = new OpenApiString("cringequeen"),
            ["status"] = new OpenApiString("Active"),
            ["displayName"] = new OpenApiString("Cringe Queen"),
            ["bio"] = new OpenApiString("Her gün en cringe anları paylaşıyorum."),
            ["verified"] = new OpenApiBoolean(true),
            ["avatarUrl"] = new OpenApiString("https://cdn.cringebank.app/avatars/cringequeen.png"),
            ["bannerUrl"] = new OpenApiString("https://cdn.cringebank.app/banners/cringequeen.png"),
            ["location"] = new OpenApiString("İstanbul"),
            ["website"] = new OpenApiString("https://cringequeen.blog"),
            ["createdAt"] = new OpenApiString("2025-01-02T11:00:00Z"),
            ["updatedAt"] = new OpenApiString("2025-10-20T19:30:00Z"),
            ["lastLoginAtUtc"] = new OpenApiString("2025-10-21T07:10:00Z")
        };
    }

    private static OpenApiObject CreateSelfProfileResponseExample()
    {
        return new OpenApiObject
        {
            ["publicId"] = new OpenApiString("d1f7cbb1-23eb-4bac-9fc1-e0eee02c0379"),
            ["email"] = new OpenApiString("user@cringebank.app"),
            ["username"] = new OpenApiString("cringehero"),
            ["status"] = new OpenApiString("Active"),
            ["displayName"] = new OpenApiString("Cringe Hero"),
            ["bio"] = new OpenApiString("Cringe avcısı."),
            ["verified"] = new OpenApiBoolean(false),
            ["avatarUrl"] = new OpenApiString("https://cdn.cringebank.app/avatars/cringehero.png"),
            ["bannerUrl"] = new OpenApiString("https://cdn.cringebank.app/banners/cringehero.png"),
            ["location"] = new OpenApiString("Ankara"),
            ["website"] = new OpenApiString("https://cringehero.example"),
            ["createdAt"] = new OpenApiString("2025-02-15T09:00:00Z"),
            ["updatedAt"] = new OpenApiString("2025-10-19T16:45:00Z"),
            ["lastLoginAtUtc"] = new OpenApiString("2025-10-21T06:55:00Z")
        };
    }

    private static OpenApiObject CreateUpdateProfileRequestExample()
    {
        return new OpenApiObject
        {
            ["displayName"] = new OpenApiString("Cringe Hero"),
            ["bio"] = new OpenApiString("Cringe avcısı."),
            ["website"] = new OpenApiString("https://cringehero.example"),
            ["avatarUrl"] = new OpenApiString("https://cdn.cringebank.app/avatars/new-cringehero.png"),
            ["bannerUrl"] = new OpenApiString("https://cdn.cringebank.app/banners/new-cringehero.png"),
            ["location"] = new OpenApiString("Ankara")
        };
    }

    private static OpenApiObject CreateProfileMediaUploadRequestExample()
    {
        return new OpenApiObject
        {
            ["contentType"] = new OpenApiString("image/png"),
            ["mediaType"] = new OpenApiString("Avatar")
        };
    }

    private static OpenApiObject CreateProfileMediaUploadResponseExample()
    {
        return new OpenApiObject
        {
            ["uploadUrl"] = new OpenApiString("https://storage.cringebank.app/upload/abc123"),
            ["resourceUrl"] = new OpenApiString("https://cdn.cringebank.app/avatars/cringehero.png"),
            ["expiresAtUtc"] = new OpenApiString("2025-10-21T08:30:00Z"),
            ["blobName"] = new OpenApiString("avatars/cringehero.png"),
            ["contentType"] = new OpenApiString("image/png")
        };
    }

    private static OpenApiObject CreateSessionBootstrapResponseExample()
    {
        return new OpenApiObject
        {
            ["userId"] = new OpenApiString("d1f7cbb1-23eb-4bac-9fc1-e0eee02c0379"),
            ["firebaseUid"] = new OpenApiString("firebase-uid-123"),
            ["email"] = new OpenApiString("user@cringebank.app"),
            ["emailVerified"] = new OpenApiBoolean(true),
            ["claimsVersion"] = new OpenApiInteger(2),
            ["status"] = new OpenApiString("Active"),
            ["displayName"] = new OpenApiString("Cringe Hero"),
            ["profileImageUrl"] = new OpenApiString("https://cdn.cringebank.app/avatars/cringehero.png"),
            ["phoneNumber"] = new OpenApiString("+905551112233"),
            ["lastLoginAtUtc"] = new OpenApiString("2025-10-21T07:00:00Z"),
            ["lastSyncedAtUtc"] = new OpenApiString("2025-10-21T07:01:00Z"),
            ["lastSeenAppVersion"] = new OpenApiString("2.5.0")
        };
    }

    private static OpenApiObject CreateRootResponseExample()
    {
        return new OpenApiObject
        {
            ["service"] = new OpenApiString("CringeBank.Api"),
            ["environment"] = new OpenApiString("Development"),
            ["version"] = new OpenApiString("1.0.0")
        };
    }

    private static IResult MapUpdateProfileFailure(UpdateAuthUserProfileResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        var code = result.FailureCode ?? "unknown_error";

        return code switch
        {
            "user_not_found" => Results.NotFound(),
            "user_not_active" => Results.StatusCode(StatusCodes.Status403Forbidden),
            "profile_not_found" => Results.NotFound(),
            _ => Results.BadRequest(new { error = code })
        };
    }

    private static IResult MapUploadTokenFailure(GenerateProfileMediaUploadUrlResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        var code = result.FailureCode ?? "unknown_error";

        return code switch
        {
            "storage_not_configured" => Results.StatusCode(StatusCodes.Status503ServiceUnavailable),
            "invalid_user_identifier" => Results.BadRequest(new { error = code }),
            "invalid_content_type" => Results.BadRequest(new { error = code }),
            "unsupported_media_type" => Results.BadRequest(new { error = code }),
            _ => Results.BadRequest(new { error = code })
        };
    }

    private static async Task<IResult> HandleGetWalletBalanceAsync(
        ClaimsPrincipal principal,
        IDispatcher dispatcher,
        CancellationToken cancellationToken)
    {
        var publicId = GetUserPublicId(principal);

        if (publicId is null)
        {
            return Results.Unauthorized();
        }

        try
        {
            var query = new GetWalletBalanceQuery(publicId.Value);
            var balance = await dispatcher.QueryAsync<GetWalletBalanceQuery, WalletBalanceResult>(query, cancellationToken);
            return Results.Ok(WalletResponseMapper.Map(balance));
        }
        catch (InvalidOperationException ex)
        {
            return MapWalletUserFailure(ex);
        }
    }

    private static async Task<IResult> HandleGetWalletTransactionsAsync(
        ClaimsPrincipal principal,
        int? pageSize,
        string? cursor,
        IDispatcher dispatcher,
        CancellationToken cancellationToken)
    {
        var publicId = GetUserPublicId(principal);

        if (publicId is null)
        {
            return Results.Unauthorized();
        }

        try
        {
            var size = NormalizePageSize(pageSize);
            var query = new GetWalletTransactionsQuery(publicId.Value, size, cursor);
            var page = await dispatcher.QueryAsync<GetWalletTransactionsQuery, WalletTransactionsPageResult>(query, cancellationToken);
            return Results.Ok(WalletResponseMapper.Map(page));
        }
        catch (InvalidOperationException ex)
        {
            return MapWalletUserFailure(ex);
        }
    }

    private static async Task<IResult> HandleReleaseEscrowAsync(
        Guid orderId,
        ClaimsPrincipal principal,
        ReleaseEscrowRequest? request,
        IDispatcher dispatcher,
        CancellationToken cancellationToken)
    {
        var actorPublicId = GetUserPublicId(principal);

        if (actorPublicId is null)
        {
            return Results.Unauthorized();
        }

        var isOverride = request?.IsSystemOverride ?? false;
        var command = new ReleaseEscrowCommand(orderId, actorPublicId.Value, isOverride);
        var result = await dispatcher.SendAsync<ReleaseEscrowCommand, ReleaseEscrowResult>(command, cancellationToken);

        if (result.Success)
        {
            return Results.Ok(new { success = true });
        }

        return MapEscrowFailure(result.FailureCode, result.ErrorMessage);
    }

    private static async Task<IResult> HandleRefundEscrowAsync(
        Guid orderId,
        ClaimsPrincipal principal,
        RefundEscrowRequest? request,
        IDispatcher dispatcher,
        CancellationToken cancellationToken)
    {
        var actorPublicId = GetUserPublicId(principal);

        if (actorPublicId is null)
        {
            return Results.Unauthorized();
        }

        var isOverride = request?.IsSystemOverride ?? false;
        var reason = string.IsNullOrWhiteSpace(request?.RefundReason) ? null : request!.RefundReason!.Trim();
        var command = new RefundEscrowCommand(orderId, actorPublicId.Value, isOverride, reason);
        var result = await dispatcher.SendAsync<RefundEscrowCommand, RefundEscrowResult>(command, cancellationToken);

        if (result.Success)
        {
            return Results.Ok(new { success = true });
        }

        return MapEscrowFailure(result.FailureCode, result.ErrorMessage);
    }

    private static IResult MapWalletUserFailure(InvalidOperationException exception)
    {
        ArgumentNullException.ThrowIfNull(exception);

        var message = exception.Message ?? string.Empty;

        return message switch
        {
            "User not found." => Results.NotFound(new { error = "user_not_found" }),
            "User is not active." => Results.StatusCode(StatusCodes.Status403Forbidden),
            _ => Results.BadRequest(new { error = "wallet_user_error", message })
        };
    }

    private static IResult MapEscrowFailure(string? failureCode, string? errorMessage)
    {
        var code = string.IsNullOrWhiteSpace(failureCode) ? "escrow_failed" : failureCode;

        return code switch
        {
            "actor_not_found" => Results.Unauthorized(),
            "actor_not_active" => Results.StatusCode(StatusCodes.Status403Forbidden),
            "not_authorized" => Results.StatusCode(StatusCodes.Status403Forbidden),
            "order_not_found" => Results.NotFound(new { error = code }),
            "escrow_not_found" => Results.NotFound(new { error = code }),
            "invalid_order_status" => Results.StatusCode(StatusCodes.Status409Conflict),
            "invalid_payment_status" => Results.StatusCode(StatusCodes.Status409Conflict),
            "escrow_not_locked" => Results.StatusCode(StatusCodes.Status409Conflict),
            "buyer_wallet_missing" => Results.StatusCode(StatusCodes.Status409Conflict),
            "insufficient_pending" => Results.StatusCode(StatusCodes.Status409Conflict),
            "actor_missing" => Results.BadRequest(new { error = code }),
            "invalid_request" => Results.BadRequest(new { error = code }),
            _ => Results.BadRequest(new { error = code, message = errorMessage })
        };
    }

    private static async Task<IResult> HandleGetAdminUsersAsync(
        ClaimsPrincipal principal,
        string? term,
        string? status,
        string? role,
        int? pageSize,
        string? cursor,
        IDispatcher dispatcher,
        CancellationToken cancellationToken)
    {
        var actorPublicId = GetUserPublicId(principal);

        if (actorPublicId is null)
        {
            return Results.Unauthorized();
        }

        AuthUserStatus? statusFilter = null;

        if (!string.IsNullOrWhiteSpace(status))
        {
            if (!Enum.TryParse<AuthUserStatus>(status, ignoreCase: true, out var parsedStatus))
            {
                return Results.BadRequest(new { error = "status_invalid" });
            }

            statusFilter = parsedStatus;
        }

        var size = NormalizePageSize(pageSize);
        var query = new GetAdminUsersQuery(actorPublicId.Value, term, statusFilter, role, size, cursor);

        try
        {
            var page = await dispatcher.QueryAsync<GetAdminUsersQuery, AdminUserPageResult>(query, cancellationToken).ConfigureAwait(false);
            return Results.Ok(AdminResponseMapper.Map(page));
        }
        catch (InvalidOperationException ex)
        {
            return MapAdminUserFailure(ex);
        }
    }

    private static async Task<IResult> HandleAssignUserRoleAsync(
        Guid userId,
        ClaimsPrincipal principal,
        AssignRoleRequest? request,
        IDispatcher dispatcher,
        CancellationToken cancellationToken)
    {
        var actorPublicId = GetUserPublicId(principal);

        if (actorPublicId is null)
        {
            return Results.Unauthorized();
        }

        if (request is null || string.IsNullOrWhiteSpace(request.Role))
        {
            return Results.BadRequest(new { error = "role_required" });
        }

        var role = request.Role.Trim();
        var command = new AssignUserRoleCommand(actorPublicId.Value, userId, role);
        var result = await dispatcher.SendAsync<AssignUserRoleCommand, AssignUserRoleResult>(command, cancellationToken).ConfigureAwait(false);

        if (!result.Success || result.User is null)
        {
            return MapAdminCommandFailure(result.FailureCode);
        }

        return Results.Ok(AdminResponseMapper.Map(result.User));
    }

    private static async Task<IResult> HandleRemoveUserRoleAsync(
        Guid userId,
        string roleName,
        ClaimsPrincipal principal,
        IDispatcher dispatcher,
        CancellationToken cancellationToken)
    {
        var actorPublicId = GetUserPublicId(principal);

        if (actorPublicId is null)
        {
            return Results.Unauthorized();
        }

        if (string.IsNullOrWhiteSpace(roleName))
        {
            return Results.BadRequest(new { error = "role_required" });
        }

        var command = new RemoveUserRoleCommand(actorPublicId.Value, userId, roleName.Trim());
        var result = await dispatcher.SendAsync<RemoveUserRoleCommand, RemoveUserRoleResult>(command, cancellationToken).ConfigureAwait(false);

        if (!result.Success || result.User is null)
        {
            return MapAdminCommandFailure(result.FailureCode);
        }

        return Results.Ok(AdminResponseMapper.Map(result.User));
    }

    private static async Task<IResult> HandleUpdateUserStatusAsync(
        Guid userId,
        ClaimsPrincipal principal,
        UpdateUserStatusRequest? request,
        IDispatcher dispatcher,
        CancellationToken cancellationToken)
    {
        var actorPublicId = GetUserPublicId(principal);

        if (actorPublicId is null)
        {
            return Results.Unauthorized();
        }

        if (request is null || string.IsNullOrWhiteSpace(request.Status))
        {
            return Results.BadRequest(new { error = "status_required" });
        }

        if (!Enum.TryParse<AuthUserStatus>(request.Status.Trim(), ignoreCase: true, out var status))
        {
            return Results.BadRequest(new { error = "status_invalid" });
        }

        var command = new UpdateUserStatusCommand(actorPublicId.Value, userId, status);
        var result = await dispatcher.SendAsync<UpdateUserStatusCommand, UpdateUserStatusResult>(command, cancellationToken).ConfigureAwait(false);

        if (!result.Success || result.User is null || !result.Status.HasValue)
        {
            return MapAdminCommandFailure(result.FailureCode);
        }

        return Results.Ok(new
        {
            status = result.Status.Value.ToString(),
            user = AdminResponseMapper.Map(result.User)
        });
    }

    private static IResult MapAdminUserFailure(InvalidOperationException exception)
    {
        ArgumentNullException.ThrowIfNull(exception);

        var message = exception.Message ?? string.Empty;

        return message switch
        {
            "Actor not found." => Results.Unauthorized(),
            "Actor not active." => Results.StatusCode(StatusCodes.Status403Forbidden),
            _ => Results.BadRequest(new { error = "admin_user_error", message })
        };
    }

    private static IResult MapAdminCommandFailure(string? failureCode)
    {
        var code = failureCode ?? "unknown_error";

        return code switch
        {
            "actor_not_found" => Results.Unauthorized(),
            "actor_not_active" => Results.StatusCode(StatusCodes.Status403Forbidden),
            "user_not_found" => Results.NotFound(new { error = code }),
            "role_not_found" => Results.NotFound(new { error = code }),
            "role_already_assigned" => Results.Conflict(new { error = code }),
            "role_not_assigned" => Results.Conflict(new { error = code }),
            "status_unchanged" => Results.Conflict(new { error = code }),
            "user_summary_unavailable" => Results.Json(new { error = code }, statusCode: StatusCodes.Status503ServiceUnavailable),
            _ => Results.BadRequest(new { error = code })
        };
    }

    private static async Task<IResult> HandleCreateConversationAsync(
        ClaimsPrincipal principal,
        CreateConversationRequest request,
        IDispatcher dispatcher,
        CancellationToken cancellationToken)
    {
        var initiatorPublicId = GetUserPublicId(principal);

        if (initiatorPublicId is null)
        {
            return Results.Unauthorized();
        }

        if (request is null)
        {
            return Results.BadRequest(new { error = "invalid_payload" });
        }

        var participantIds = request.ParticipantPublicIds is { Count: > 0 }
            ? request.ParticipantPublicIds.ToArray()
            : Array.Empty<Guid>();

        var command = new CreateConversationCommand(
            initiatorPublicId.Value,
            request.IsGroup,
            request.Title,
            participantIds);

        var result = await dispatcher.SendAsync<CreateConversationCommand, CreateConversationResult>(command, cancellationToken);

        if (!result.Success || result.Conversation is null)
        {
            return MapCreateConversationFailure(result.FailureCode);
        }

        return Results.Ok(ChatResponseMapper.Map(result.Conversation));
    }

    private static async Task<IResult> HandleSendMessageAsync(
        Guid conversationId,
        ClaimsPrincipal principal,
        SendMessageRequest request,
        IDispatcher dispatcher,
        CancellationToken cancellationToken)
    {
        var senderPublicId = GetUserPublicId(principal);

        if (senderPublicId is null)
        {
            return Results.Unauthorized();
        }

        if (request is null || string.IsNullOrWhiteSpace(request.Body))
        {
            return Results.BadRequest(new { error = "body_required" });
        }

        var command = new SendMessageCommand(conversationId, senderPublicId.Value, request.Body);
        var result = await dispatcher.SendAsync<SendMessageCommand, SendMessageResult>(command, cancellationToken);

        if (!result.Success || result.Message is null)
        {
            return MapSendMessageFailure(result.FailureCode);
        }

        return Results.Ok(ChatResponseMapper.Map(result.Message));
    }

    private static async Task<IResult> HandleMarkConversationReadAsync(
        Guid conversationId,
        ClaimsPrincipal principal,
        MarkConversationReadRequest request,
        IDispatcher dispatcher,
        CancellationToken cancellationToken)
    {
        var userPublicId = GetUserPublicId(principal);

        if (userPublicId is null)
        {
            return Results.Unauthorized();
        }

        if (request is null || request.MessageId <= 0)
        {
            return Results.BadRequest(new { error = "message_id_invalid" });
        }

        var command = new MarkConversationReadCommand(conversationId, userPublicId.Value, request.MessageId);
        var result = await dispatcher.SendAsync<MarkConversationReadCommand, MarkConversationReadCommandResult>(command, cancellationToken);

        if (!result.Success || result.Read is null)
        {
            return MapMarkConversationReadFailure(result.FailureCode);
        }

        return Results.Ok(ChatResponseMapper.Map(result.Read));
    }

    private static IResult MapCreateConversationFailure(string? failureCode)
    {
        var code = failureCode ?? "unknown_error";

        return code switch
        {
            "initiator_not_found" => Results.Unauthorized(),
            "initiator_not_active" => Results.StatusCode(StatusCodes.Status403Forbidden),
            "participant_not_found" => Results.NotFound(new { error = code }),
            "participant_not_active" => Results.StatusCode(StatusCodes.Status403Forbidden),
            "participants_invalid" => Results.BadRequest(new { error = code }),
            "participants_cannot_include_initiator" => Results.BadRequest(new { error = code }),
            "participants_must_be_unique" => Results.BadRequest(new { error = code }),
            "title_too_long" => Results.BadRequest(new { error = code }),
            _ => Results.BadRequest(new { error = code })
        };
    }

    private static IResult MapSendMessageFailure(string? failureCode)
    {
        var code = failureCode ?? "unknown_error";

        return code switch
        {
            "sender_not_found" => Results.Unauthorized(),
            "sender_not_active" => Results.StatusCode(StatusCodes.Status403Forbidden),
            "conversation_not_found" => Results.NotFound(new { error = code }),
            "sender_not_member" => Results.StatusCode(StatusCodes.Status403Forbidden),
            "invalid_body" => Results.BadRequest(new { error = code }),
            _ => Results.BadRequest(new { error = code })
        };
    }

    private static IResult MapMarkConversationReadFailure(string? failureCode)
    {
        var code = failureCode ?? "unknown_error";

        return code switch
        {
            "user_not_found" => Results.Unauthorized(),
            "user_not_active" => Results.StatusCode(StatusCodes.Status403Forbidden),
            "conversation_not_found" => Results.NotFound(new { error = code }),
            "user_not_member" => Results.StatusCode(StatusCodes.Status403Forbidden),
            "message_not_found" => Results.NotFound(new { error = code }),
            _ => Results.BadRequest(new { error = code })
        };
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
