using System;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Social.Entities;
using CringeBank.Domain.Social.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Social;

public sealed class SocialPostConfiguration : IEntityTypeConfiguration<SocialPost>
{
    public void Configure(EntityTypeBuilder<SocialPost> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Posts", "social");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.PublicId)
            .HasColumnName("public_id")
            .HasDefaultValueSql("NEWSEQUENTIALID()");

        builder.Property(x => x.UserId)
            .HasColumnName("user_id")
            .IsRequired();

        builder.Property(x => x.Type)
            .HasColumnName("type")
            .HasColumnType("tinyint")
            .IsRequired();

        builder.Property(x => x.Text)
            .HasColumnName("text")
            .HasMaxLength(2000);

        builder.Property(x => x.Visibility)
            .HasColumnName("visibility")
            .HasConversion<byte>()
            .HasDefaultValue(SocialPostVisibility.Public)
            .IsRequired();

        builder.Property(x => x.LikesCount)
            .HasColumnName("likes_count")
            .HasDefaultValue(0)
            .IsRequired();

        builder.Property(x => x.CommentsCount)
            .HasColumnName("comments_count")
            .HasDefaultValue(0)
            .IsRequired();

        builder.Property(x => x.SavesCount)
            .HasColumnName("saves_count")
            .HasDefaultValue(0)
            .IsRequired();

        builder.Property(x => x.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.Property(x => x.UpdatedAt)
            .HasColumnName("updated_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.Property(x => x.DeletedAt)
            .HasColumnName("deleted_at")
            .HasColumnType("datetime2(3)");

        builder.HasOne(x => x.Author)
            .WithMany(x => x.Posts)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(x => new { x.UserId, x.CreatedAt })
            .HasDatabaseName("IX_Posts_User_CreatedAt");

        builder.HasIndex(x => new { x.CreatedAt, x.Id })
            .HasDatabaseName("IX_Posts_CreatedAt_Id");
    }
}
