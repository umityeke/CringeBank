using System;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CringeBank.Infrastructure;

public static class DependencyInjection
{
  private const string ConnectionStringName = "Sql";

  public static IServiceCollection AddInfrastructure(IServiceCollection services, IConfiguration configuration)
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
    return services;
  }
}
