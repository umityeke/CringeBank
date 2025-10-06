using System;
using CringeBank.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations;

public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Orders");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.PriceGold)
            .HasPrecision(18, 2)
            .IsRequired();

        builder.Property(x => x.CommissionGold)
            .HasPrecision(18, 2)
            .IsRequired();

        builder.Property(x => x.TotalGold)
            .HasPrecision(18, 2)
            .IsRequired();

        builder.Property(x => x.Status)
            .HasConversion<string>()
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(x => x.SellerType)
            .HasConversion<string>()
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(x => x.CreatedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired();

        builder.Property(x => x.UpdatedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired();

        builder.Property(x => x.CompletedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired(false);

        builder.Property(x => x.CanceledAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired(false);

        builder.HasOne(x => x.Product)
            .WithMany()
            .HasForeignKey(x => x.ProductId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.Escrow)
            .WithOne(x => x.Order)
            .HasForeignKey<Escrow>(x => x.OrderId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => x.Status);
        builder.HasIndex(x => new { x.BuyerId, x.Status });
        builder.HasIndex(x => new { x.SellerId, x.Status });
    }
}
