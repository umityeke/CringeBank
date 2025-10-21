using System;
using CringeBank.Domain.Social.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Social;

public sealed class SocialPostSaveConfiguration : IEntityTypeConfiguration<SocialPostSave>
{
    public void Configure(EntityTypeBuilder<SocialPostSave> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("PostSaves", "social");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.PostId)
            .HasColumnName("post_id")
            .IsRequired();

        builder.Property(x => x.UserId)
            .HasColumnName("user_id")
            .IsRequired();

        builder.Property(x => x.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.HasOne(x => x.Post)
            .WithMany(x => x.Saves)
            .HasForeignKey(x => x.PostId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.User)
            .WithMany(x => x.PostSaves)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => new { x.PostId, x.UserId })
            .IsUnique()
            .HasDatabaseName("UX_PostSaves_Post_User");
    }
}
