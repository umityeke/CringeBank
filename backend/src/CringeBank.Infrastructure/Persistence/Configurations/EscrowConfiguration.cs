using System;
using CringeBank.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations;

public sealed class EscrowConfiguration : IEntityTypeConfiguration<Escrow>
{
    public void Configure(EntityTypeBuilder<Escrow> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Escrows");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.AmountGold)
            .HasPrecision(18, 2)
            .IsRequired();

        builder.Property(x => x.Status)
            .HasConversion<string>()
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(x => x.CreatedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired();

        builder.Property(x => x.UpdatedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired();

        builder.Property(x => x.ReleasedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired(false);

        builder.Property(x => x.RefundedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired(false);

        builder.HasIndex(x => x.Status);
    }
}
