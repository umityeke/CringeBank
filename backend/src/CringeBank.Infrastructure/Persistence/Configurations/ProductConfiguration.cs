using System;
using CringeBank.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations;

public sealed class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Products");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Title)
            .IsRequired()
            .HasMaxLength(256);

        builder.Property(x => x.Description)
            .IsRequired()
            .HasMaxLength(2048);

        builder.Property(x => x.PriceGold)
            .HasPrecision(18, 2)
            .IsRequired();

        builder.Property(x => x.Category)
            .IsRequired()
            .HasMaxLength(64);

        builder.Property(x => x.Condition)
            .HasConversion<string>()
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(x => x.Status)
            .HasConversion<string>()
            .HasMaxLength(32)
            .IsRequired();

        builder.Property(x => x.SellerType)
            .HasConversion<string>()
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(x => x.SellerId)
            .IsRequired(false);

        builder.Property(x => x.VendorId)
            .IsRequired(false);

        builder.Property(x => x.CreatedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired();

        builder.Property(x => x.UpdatedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired();

        builder.HasMany(x => x.Images)
            .WithOne(x => x.Product)
            .HasForeignKey(x => x.ProductId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Navigation(x => x.Images)
            .UsePropertyAccessMode(PropertyAccessMode.Field);

        builder.HasIndex(x => x.Status);
        builder.HasIndex(x => new { x.SellerType, x.Category });
    }
}
