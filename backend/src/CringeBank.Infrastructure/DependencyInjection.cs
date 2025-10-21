using System;
using System.Collections.Generic;
using CringeBank.Application.Admin;
using CringeBank.Application.Auth;
using CringeBank.Application.Authorization;
using CringeBank.Application.Chats;
using CringeBank.Application.Outbox;
using CringeBank.Application.Users;
using CringeBank.Application.Wallet;
using System.Globalization;
using System.Linq;
using System.Security.Cryptography;
using CringeBank.Infrastructure.Auth;
using CringeBank.Infrastructure.Authorization;
using CringeBank.Infrastructure.Chats;
using CringeBank.Infrastructure.Outbox;
using CringeBank.Infrastructure.Persistence;
using CringeBank.Application.Feeds;
using CringeBank.Infrastructure.Feeds;
using CringeBank.Infrastructure.Storage;
using CringeBank.Infrastructure.Users;
using CringeBank.Infrastructure.Wallets;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Primitives;

namespace CringeBank.Infrastructure;

public static class DependencyInjection
{
  private const string ConnectionStringName = "Sql";

  public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
  {
    ArgumentNullException.ThrowIfNull(services);
    ArgumentNullException.ThrowIfNull(configuration);

    var connectionString = configuration.GetConnectionString(ConnectionStringName);

    if (string.IsNullOrWhiteSpace(connectionString))
    {
      throw new InvalidOperationException(
        "Connection string 'Sql' not found. Configure it via appsettings, secrets, or the CRINGEBANK__CONNECTIONSTRINGS__SQL environment variable.");
    }

    services.AddDbContext<CringeBankDbContext>(options =>
      options.UseSqlServer(connectionString, sql =>
      {
        sql.MigrationsAssembly(typeof(CringeBankDbContext).Assembly.FullName);
        sql.MigrationsHistoryTable("__EFMigrationsHistory", CringeBankDbContext.Schema);
        sql.EnableRetryOnFailure();
      }));
    services.AddMemoryCache();

    var rbacSection = configuration.GetSection("Rbac");
    services.AddSingleton<IOptionsChangeTokenSource<RbacOptions>>(new ConfigurationSectionChangeTokenSource<RbacOptions>(rbacSection));
    services.AddOptions<RbacOptions>()
      .Configure(options =>
      {
        var built = BuildRbacOptions(rbacSection);
        options.RolesCacheSeconds = built.RolesCacheSeconds;
        options.Policies = built.Policies
          .Select(policy => new PolicyDefinition
          {
            Resource = policy.Resource,
            Action = policy.Action,
            Description = policy.Description,
            Roles = policy.Roles?.ToList() ?? new List<string>()
          })
          .ToList();
        options.TwoManApprovalActions = built.TwoManApprovalActions?.ToList() ?? new List<string>();
      });
    services.AddScoped<IPolicyEvaluator, PolicyEvaluator>();

    var jwtSection = configuration.GetSection("Jwt");
    var jwtOptions = new JwtOptions
    {
      Issuer = jwtSection["Issuer"] ?? string.Empty,
      Audience = jwtSection["Audience"] ?? string.Empty
    };

    if (int.TryParse(jwtSection["AccessMinutes"], NumberStyles.Integer, CultureInfo.InvariantCulture, out var accessMinutes))
    {
      jwtOptions.AccessMinutes = accessMinutes;
    }

    if (int.TryParse(jwtSection["RefreshDays"], NumberStyles.Integer, CultureInfo.InvariantCulture, out var refreshDays))
    {
      jwtOptions.RefreshDays = refreshDays;
    }

    if (int.TryParse(jwtSection["RefreshSlidingMinutes"], NumberStyles.Integer, CultureInfo.InvariantCulture, out var refreshSlidingMinutes))
    {
      jwtOptions.RefreshSlidingMinutes = refreshSlidingMinutes;
    }

    if (bool.TryParse(jwtSection["AllowEphemeralSigningKey"], out var allowEphemeral))
    {
      jwtOptions.AllowEphemeralSigningKey = allowEphemeral;
    }

    foreach (var keySection in jwtSection.GetSection("Keys").GetChildren())
    {
      var keyOptions = new JwtKeyOptions
      {
        KeyId = keySection["KeyId"] ?? string.Empty,
        Type = keySection["Type"] ?? "rsa",
        PrivateKey = keySection["PrivateKey"],
        PrivateKeyEnvironmentVariable = keySection["PrivateKeyEnvironmentVariable"],
        PublicKey = keySection["PublicKey"],
        PublicKeyEnvironmentVariable = keySection["PublicKeyEnvironmentVariable"]
      };

      if (bool.TryParse(keySection["IsPrimary"], out var isPrimary))
      {
        keyOptions.IsPrimary = isPrimary;
      }

      if (DateTimeOffset.TryParse(keySection["NotBefore"], CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var notBefore))
      {
        keyOptions.NotBefore = notBefore;
      }

      if (DateTimeOffset.TryParse(keySection["NotAfter"], CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var notAfter))
      {
        keyOptions.NotAfter = notAfter;
      }

      jwtOptions.Keys.Add(keyOptions);
    }

    var singleKeyValue = jwtSection["Key"];
    if (!string.IsNullOrWhiteSpace(singleKeyValue) && jwtOptions.Keys.Count == 0)
    {
      jwtOptions.Keys.Add(new JwtKeyOptions
      {
        KeyId = "primary",
        IsPrimary = true,
        Type = "hmac",
        PrivateKey = singleKeyValue
      });
    }

    if (jwtOptions.Keys.Count == 0)
    {
      if (jwtOptions.AllowEphemeralSigningKey)
      {
        var buffer = new byte[64];
        RandomNumberGenerator.Fill(buffer);
        jwtOptions.Keys.Add(new JwtKeyOptions
        {
          KeyId = "ephemeral",
          IsPrimary = true,
          Type = "hmac",
          PrivateKey = Convert.ToBase64String(buffer)
        });
      }
      else
      {
        throw new InvalidOperationException("Jwt:Keys yapılandırması gerekli.");
      }
    }

    if (!jwtOptions.Keys.Any(k => k.IsPrimary))
    {
      jwtOptions.Keys[0].IsPrimary = true;
    }

    foreach (var key in jwtOptions.Keys.Where(k => string.IsNullOrWhiteSpace(k.KeyId)))
    {
      key.KeyId = Guid.NewGuid().ToString("N");
    }

    services.AddSingleton<IOptions<JwtOptions>>(Options.Create(jwtOptions));

    var profileMediaSection = configuration.GetSection("Storage:ProfileMedia");
    var profileMediaOptions = new ProfileMediaStorageOptions();

    if (profileMediaSection.Exists())
    {
      profileMediaOptions.ConnectionString = profileMediaSection["ConnectionString"];
      profileMediaOptions.ContainerName = profileMediaSection["ContainerName"];

      var avatarPrefix = profileMediaSection["AvatarPrefix"];
      if (!string.IsNullOrWhiteSpace(avatarPrefix))
      {
        profileMediaOptions.AvatarPrefix = avatarPrefix;
      }

      var bannerPrefix = profileMediaSection["BannerPrefix"];
      if (!string.IsNullOrWhiteSpace(bannerPrefix))
      {
        profileMediaOptions.BannerPrefix = bannerPrefix;
      }

      if (int.TryParse(profileMediaSection["UploadExpiryMinutes"], NumberStyles.Integer, CultureInfo.InvariantCulture, out var uploadExpiry))
      {
        profileMediaOptions.UploadExpiryMinutes = uploadExpiry;
      }
    }

    services.AddSingleton<IOptions<ProfileMediaStorageOptions>>(Options.Create(profileMediaOptions));

    services.AddScoped<ILoginAuditWriter, SqlLoginAuditWriter>();
    services.AddScoped<IOutboxEventWriter, SqlOutboxEventWriter>();
    services.AddScoped<IUserSynchronizationService, UserSynchronizationService>();
  services.AddScoped<IUserReadRepository, UserReadRepository>();
  services.AddScoped<IAdminUserReadRepository, AdminUserReadRepository>();
  services.AddScoped<IChatRepository, ChatRepository>();
  services.AddScoped<IWalletRepository, WalletRepository>();
  services.AddScoped<IStoreEscrowGateway, StoreEscrowGateway>();
  services.AddScoped<IFeedReadRepository, FeedReadRepository>();
    services.AddScoped<IAuthUserRepository, AuthUserRepository>();
    services.AddSingleton<IPasswordHasher, PasswordHasher>();
    services.AddSingleton<IMfaCodeValidator, TotpMfaCodeValidator>();
    services.AddSingleton<IAuthTokenService, AuthTokenService>();
    services.AddSingleton<IProfileMediaStorageService, AzureBlobProfileMediaStorageService>();
    return services;
  }

  private static RbacOptions BuildRbacOptions(IConfigurationSection rbacSection)
  {
    var options = new RbacOptions();

    if (rbacSection is null || !rbacSection.Exists())
    {
      return options;
    }

    if (int.TryParse(rbacSection["RolesCacheSeconds"], NumberStyles.Integer, CultureInfo.InvariantCulture, out var cacheSeconds))
    {
      options.RolesCacheSeconds = cacheSeconds;
    }

    foreach (var policySection in rbacSection.GetSection("Policies").GetChildren())
    {
      var policy = new PolicyDefinition
      {
        Resource = policySection["Resource"] ?? string.Empty,
        Action = policySection["Action"] ?? string.Empty,
        Description = policySection["Description"]
      };

      foreach (var roleNode in policySection.GetSection("Roles").GetChildren())
      {
        if (!string.IsNullOrWhiteSpace(roleNode.Value))
        {
          policy.Roles.Add(roleNode.Value);
        }
      }

      if (!string.IsNullOrWhiteSpace(policy.Resource) && !string.IsNullOrWhiteSpace(policy.Action))
      {
        options.Policies.Add(policy);
      }
    }

    foreach (var actionNode in rbacSection.GetSection("TwoManApprovalActions").GetChildren())
    {
      if (!string.IsNullOrWhiteSpace(actionNode.Value))
      {
        options.TwoManApprovalActions.Add(actionNode.Value);
      }
    }

    return options;
  }

  private sealed class ConfigurationSectionChangeTokenSource<TOptions> : IOptionsChangeTokenSource<TOptions>
  {
    private readonly IConfigurationSection _section;

    public ConfigurationSectionChangeTokenSource(IConfigurationSection section)
    {
      _section = section ?? throw new ArgumentNullException(nameof(section));
    }

    public string Name => Options.DefaultName;

    public IChangeToken GetChangeToken()
    {
      return _section.GetReloadToken();
    }
  }
}
