using System;
using CringeBank.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations;

public sealed class ProductImageConfiguration : IEntityTypeConfiguration<ProductImage>
{
    public void Configure(EntityTypeBuilder<ProductImage> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("ProductImages");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Url)
            .IsRequired()
            .HasMaxLength(512);

        builder.Property(x => x.SortOrder)
            .IsRequired();

        builder.Property(x => x.CreatedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired();

        builder.Property(x => x.UpdatedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired();

        builder.HasIndex(x => new { x.ProductId, x.SortOrder }).IsUnique();
    }
}
