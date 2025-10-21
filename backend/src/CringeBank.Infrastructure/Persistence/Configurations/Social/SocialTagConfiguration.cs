using System;
using CringeBank.Domain.Social.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Social;

public sealed class SocialTagConfiguration : IEntityTypeConfiguration<SocialTag>
{
    public void Configure(EntityTypeBuilder<SocialTag> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Tags", "social");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.Name)
            .HasColumnName("name")
            .HasMaxLength(128)
            .IsRequired();

        builder.Property(x => x.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.HasMany(x => x.PostTags)
            .WithOne(x => x.Tag)
            .HasForeignKey(x => x.TagId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => x.Name)
            .IsUnique();
    }
}
