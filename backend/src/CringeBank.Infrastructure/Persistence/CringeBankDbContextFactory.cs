using System;
using System.Diagnostics.CodeAnalysis;
using System.IO;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace CringeBank.Infrastructure.Persistence;

public sealed class CringeBankDbContextFactory : IDesignTimeDbContextFactory<CringeBankDbContext>
{
  public CringeBankDbContext CreateDbContext(string[] args)
  {
    var configuration = BuildConfiguration();

    var connectionString = configuration.GetConnectionString("Sql");

    if (string.IsNullOrWhiteSpace(connectionString))
    {
      throw new InvalidOperationException(
        "Connection string 'Sql' not found. Configure it via appsettings, user secrets, or the CRINGEBANK__CONNECTIONSTRINGS__SQL environment variable.");
    }

    var optionsBuilder = new DbContextOptionsBuilder<CringeBankDbContext>();

    optionsBuilder.UseSqlServer(connectionString, sql =>
    {
      sql.MigrationsHistoryTable("__EFMigrationsHistory", CringeBankDbContext.Schema);
      sql.MigrationsAssembly(typeof(CringeBankDbContext).Assembly.FullName);
      sql.EnableRetryOnFailure();
    });

    return new CringeBankDbContext(optionsBuilder.Options);
  }

  [SuppressMessage("Performance", "CA1859:Use concrete types when possible", Justification = "Design-time factory should expose IConfiguration for EF tooling compatibility.")]
  private static IConfiguration BuildConfiguration()
  {
    const string development = "Development";

    var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
      ?? Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT")
      ?? development;

    var configuration = new ConfigurationManager();

    configuration.SetBasePath(Directory.GetCurrentDirectory());
    configuration.AddJsonFile("appsettings.json", optional: true);
    configuration.AddJsonFile($"appsettings.{environment}.json", optional: true);

    var apiDirectory = Path.Combine("..", "CringeBank.Api");
    configuration.AddJsonFile(Path.Combine(apiDirectory, "appsettings.json"), optional: true);
    configuration.AddJsonFile(Path.Combine(apiDirectory, $"appsettings.{environment}.json"), optional: true);

  if (string.Equals(environment, development, StringComparison.OrdinalIgnoreCase))
    {
      configuration.AddUserSecrets<CringeBankDbContextFactory>(optional: true);
    }

    configuration.AddEnvironmentVariables(prefix: "CRINGEBANK_");

    return configuration;
  }
}
