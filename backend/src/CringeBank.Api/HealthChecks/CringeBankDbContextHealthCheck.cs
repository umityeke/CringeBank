using System;
using System.Data;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;

namespace CringeBank.Api.HealthChecks;

public sealed class CringeBankDbContextHealthCheck : IHealthCheck
{
	private static readonly Action<ILogger, Exception?> LogDatabaseFailure = LoggerMessage.Define(
		LogLevel.Error,
		new EventId(5500, nameof(LogDatabaseFailure)),
		"Database health check failed.");

	private readonly IServiceScopeFactory _scopeFactory;
	private readonly ILogger<CringeBankDbContextHealthCheck> _logger;

	public CringeBankDbContextHealthCheck(IServiceScopeFactory scopeFactory, ILogger<CringeBankDbContextHealthCheck> logger)
	{
		_scopeFactory = scopeFactory ?? throw new ArgumentNullException(nameof(scopeFactory));
		_logger = logger ?? throw new ArgumentNullException(nameof(logger));
	}

	public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
	{
		ArgumentNullException.ThrowIfNull(context);

		await using var scope = _scopeFactory.CreateAsyncScope();
		var dbContext = scope.ServiceProvider.GetRequiredService<CringeBankDbContext>();

		try
		{
			var connection = dbContext.Database.GetDbConnection();
			if (connection.State != ConnectionState.Open)
			{
				await connection.OpenAsync(cancellationToken).ConfigureAwait(false);
			}

			await using var command = connection.CreateCommand();
			command.CommandText = "SELECT 1";
			command.CommandType = CommandType.Text;
			command.CommandTimeout = 5;

			_ = await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false);
			return HealthCheckResult.Healthy("Database reachable");
		}
		catch (Exception ex)
		{
			LogDatabaseFailure(_logger, ex);
			return HealthCheckResult.Unhealthy("Database query failed", ex);
		}
	}
}
