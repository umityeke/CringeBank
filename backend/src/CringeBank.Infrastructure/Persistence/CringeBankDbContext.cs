using System;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Domain.Abstractions;
using CringeBank.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace CringeBank.Infrastructure.Persistence;

public sealed class CringeBankDbContext : DbContext
{
    public const string Schema = "cringebank";

    public CringeBankDbContext(DbContextOptions<CringeBankDbContext> options)
        : base(options)
    {
    }

    public DbSet<Product> Products => Set<Product>();

    public DbSet<ProductImage> ProductImages => Set<ProductImage>();

    public DbSet<Order> Orders => Set<Order>();

    public DbSet<Escrow> Escrows => Set<Escrow>();

    public DbSet<Wallet> Wallets => Set<Wallet>();

    public DbSet<User> Users => Set<User>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        ArgumentNullException.ThrowIfNull(modelBuilder);

        modelBuilder.HasDefaultSchema(Schema);
        modelBuilder.ApplyConfigurationsFromAssembly(Assembly.GetExecutingAssembly());
        base.OnModelCreating(modelBuilder);
    }

    public override int SaveChanges()
    {
        ApplyAuditing();
        return base.SaveChanges();
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        ApplyAuditing();
        return base.SaveChangesAsync(cancellationToken);
    }

    private void ApplyAuditing()
    {
        var utcNow = DateTimeOffset.UtcNow;

        foreach (var entry in ChangeTracker.Entries<Entity>())
        {
            if (entry.State == EntityState.Added)
            {
                entry.Property(nameof(Entity.CreatedAtUtc)).CurrentValue = utcNow;
                entry.Property(nameof(Entity.UpdatedAtUtc)).CurrentValue = utcNow;
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Property(nameof(Entity.CreatedAtUtc)).IsModified = false;
                entry.Property(nameof(Entity.UpdatedAtUtc)).CurrentValue = utcNow;
            }
        }
    }
}
