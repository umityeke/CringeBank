using System;
using CringeBank.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations;

public sealed class WalletConfiguration : IEntityTypeConfiguration<Wallet>
{
    public void Configure(EntityTypeBuilder<Wallet> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Wallets");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.OwnerKey)
            .IsRequired()
            .HasMaxLength(128);

        builder.Property(x => x.OwnerType)
            .HasConversion<string>()
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(x => x.GoldBalance)
            .HasPrecision(18, 2)
            .HasDefaultValue(0M);

        builder.Property(x => x.CreatedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired();

        builder.Property(x => x.UpdatedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired();

        builder.HasIndex(x => new { x.OwnerKey, x.OwnerType }).IsUnique();
    }
}
