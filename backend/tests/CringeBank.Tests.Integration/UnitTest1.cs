using System;
using System.Data;
using System.Threading.Tasks;
using CringeBank.Infrastructure.Persistence;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace CringeBank.Tests.Integration;

public sealed class DatabaseMigrationTests : IAsyncLifetime
{
    private readonly string _databaseName = $"CringeBank_Migrations_{Guid.NewGuid():N}";
    private readonly string _masterConnectionString = "Server=(localdb)\\MSSQLLocalDB;Integrated Security=true;";
    private readonly string _testConnectionString;

    public DatabaseMigrationTests()
    {
        var builder = new SqlConnectionStringBuilder
        {
            DataSource = "(localdb)\\MSSQLLocalDB",
            InitialCatalog = _databaseName,
            IntegratedSecurity = true,
            MultipleActiveResultSets = true,
            TrustServerCertificate = true
        };

        _testConnectionString = builder.ConnectionString;
    }

    [Fact]
    public async Task applying_all_migrations_succeeds_and_leaves_no_pending_items()
    {
        var options = new DbContextOptionsBuilder<CringeBankDbContext>()
            .UseSqlServer(
                _testConnectionString,
                sql =>
                {
                    sql.MigrationsAssembly(typeof(CringeBankDbContext).Assembly.FullName);
                    sql.MigrationsHistoryTable("__EFMigrationsHistory", CringeBankDbContext.Schema);
                    sql.EnableRetryOnFailure();
                })
            .Options;

        await using var context = new CringeBankDbContext(options);

        await context.Database.MigrateAsync();

        var pending = await context.Database.GetPendingMigrationsAsync();
        Assert.Empty(pending);

        var applied = await context.Database.GetAppliedMigrationsAsync();
        Assert.NotEmpty(applied);
    }

    public async Task InitializeAsync()
    {
        await using var connection = new SqlConnection(_masterConnectionString);
        await connection.OpenAsync();

        await using var command = connection.CreateCommand();
        command.CommandText = $"IF DB_ID('{_databaseName}') IS NULL CREATE DATABASE [{_databaseName}]";
        command.CommandType = CommandType.Text;

        await command.ExecuteNonQueryAsync();
    }

    public async Task DisposeAsync()
    {
        await using var connection = new SqlConnection(_masterConnectionString);
        await connection.OpenAsync();

        await using var command = connection.CreateCommand();
        command.CommandText = $@"
IF DB_ID('{_databaseName}') IS NOT NULL
BEGIN
    ALTER DATABASE [{_databaseName}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [{_databaseName}];
END";
        command.CommandType = CommandType.Text;

        await command.ExecuteNonQueryAsync();
    }
}
