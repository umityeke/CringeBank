namespace CringeBank.Tests.Integration.Infrastructure;

using System;
using System.Collections.Generic;
using System.Linq;
using CringeBank.Api;
using CringeBank.Api.Background;
using CringeBank.Application.Authorization;
using CringeBank.Infrastructure.Persistence;
using CringeBank.Infrastructure.Persistence.Seeding;
using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Google.Apis.Auth.OAuth2;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

public sealed class TestApplicationFactory : WebApplicationFactory<Program>
{
    private FirebaseApp? _firebaseApp;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

    Environment.SetEnvironmentVariable("CRINGEBANK__CONNECTIONSTRINGS__SQL", "Server=(localdb)\\MSSQLLocalDB;Database=CringeBankIntegrationTest;Trusted_Connection=True;MultipleActiveResultSets=true");
    Environment.SetEnvironmentVariable("CRINGEBANK__JWT__ALLOWEPHEMERALSIGNINGKEY", "true");
    Environment.SetEnvironmentVariable("CRINGEBANK__AUTHENTICATION__FIREBASE__PROJECTID", "cringebank-integration-test");
    Environment.SetEnvironmentVariable("CRINGEBANK__AUTHENTICATION__FIREBASE__REQUIREEMAILVERIFIED", "false");
    Environment.SetEnvironmentVariable("CRINGEBANK__AUTHENTICATION__APPCHECK__ENABLED", "false");
    Environment.SetEnvironmentVariable("CRINGEBANK__WORKERS__FIREBASEUSERSYNCHRONIZATION__ENABLED", "false");

        builder.UseEnvironment("IntegrationTest");

        builder.ConfigureAppConfiguration((_, configurationBuilder) =>
        {
            var settings = new Dictionary<string, string?>
            {
                ["ConnectionStrings:Sql"] = "Server=(localdb)\\MSSQLLocalDB;Database=CringeBankIntegrationTest;Trusted_Connection=True;MultipleActiveResultSets=true",
                ["Authentication:Firebase:ProjectId"] = "cringebank-integration-test",
                ["Authentication:Firebase:RequireEmailVerified"] = "false",
                ["Authentication:AppCheck:Enabled"] = "false",
                ["Jwt:AllowEphemeralSigningKey"] = "true",
                ["Workers:FirebaseUserSynchronization:Enabled"] = "false"
            };

            configurationBuilder.AddInMemoryCollection(settings!);
        });

        builder.ConfigureServices(services =>
        {
            services.RemoveAll(typeof(DbContextOptions<CringeBankDbContext>));
            services.RemoveAll(typeof(IConfigureOptions<DbContextOptions<CringeBankDbContext>>));
            services.RemoveAll(typeof(IPostConfigureOptions<DbContextOptions<CringeBankDbContext>>));
            services.RemoveAll(typeof(OptionsFactory<DbContextOptions<CringeBankDbContext>>));
            services.RemoveAll(typeof(CringeBankDbContext));
            services.AddDbContext<CringeBankDbContext>(options =>
            {
                options.UseInMemoryDatabase("CringeBankIntegrationTests");
            });

            services.RemoveAll(typeof(IDatabaseInitializer));
            services.AddSingleton<IDatabaseInitializer, NoOpDatabaseInitializer>();

            services.RemoveAll(typeof(IPolicyEvaluator));
            services.AddSingleton<IPolicyEvaluator, AllowAllPolicyEvaluator>();

            RemoveHostedServices(services);

            services.RemoveAll(typeof(FirebaseApp));
            services.RemoveAll(typeof(FirebaseAuth));
            services.AddSingleton(provider => EnsureFirebaseApp());
            services.AddSingleton(provider => FirebaseAuth.GetAuth(provider.GetRequiredService<FirebaseApp>()));

            services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = TestAuthDefaults.AuthenticationScheme;
                options.DefaultChallengeScheme = TestAuthDefaults.AuthenticationScheme;
                options.DefaultScheme = TestAuthDefaults.AuthenticationScheme;
            }).AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthDefaults.AuthenticationScheme, _ => { });
        });
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);

        if (!disposing)
        {
            return;
        }

        if (_firebaseApp is not null)
        {
            _firebaseApp.Delete();
            _firebaseApp = null;
        }
    }

    private FirebaseApp EnsureFirebaseApp()
    {
        if (_firebaseApp is not null)
        {
            return _firebaseApp;
        }

        try
        {
            _firebaseApp = FirebaseApp.GetInstance("CringeBankIntegrationTestApp");
        }
        catch (Exception)
        {
            var credential = GoogleCredential.FromAccessToken("integration-test-token");
            _firebaseApp = FirebaseApp.Create(new AppOptions
            {
                ProjectId = "cringebank-integration-test",
                Credential = credential
            }, "CringeBankIntegrationTestApp");
        }

        return _firebaseApp;
    }

    private static void RemoveHostedServices(IServiceCollection services)
    {
        var hostedServiceDescriptors = services
            .Where(descriptor => descriptor.ServiceType == typeof(IHostedService))
            .Where(descriptor => descriptor.ImplementationType == typeof(FirebaseUserSynchronizationWorker))
            .ToList();

        foreach (var descriptor in hostedServiceDescriptors)
        {
            services.Remove(descriptor);
        }
    }
}
