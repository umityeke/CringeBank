using System;
using CringeBank.Domain.Social.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Social;

public sealed class SocialPostCommentConfiguration : IEntityTypeConfiguration<SocialPostComment>
{
    public void Configure(EntityTypeBuilder<SocialPostComment> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("PostComments", "social");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.PostId)
            .HasColumnName("post_id")
            .IsRequired();

        builder.Property(x => x.ParentCommentId)
            .HasColumnName("parent_comment_id");

        builder.Property(x => x.UserId)
            .HasColumnName("user_id")
            .IsRequired();

        builder.Property(x => x.Text)
            .HasColumnName("text")
            .HasMaxLength(1000)
            .IsRequired();

        builder.Property(x => x.LikeCount)
            .HasColumnName("like_count")
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

        builder.HasOne(x => x.Post)
            .WithMany(x => x.Comments)
            .HasForeignKey(x => x.PostId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.Parent)
            .WithMany(x => x.Replies)
            .HasForeignKey(x => x.ParentCommentId)
            .OnDelete(DeleteBehavior.ClientSetNull);

        builder.HasOne(x => x.User)
            .WithMany(x => x.PostComments)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => new { x.PostId, x.CreatedAt })
            .HasDatabaseName("IX_PostComments_Post_CreatedAt");
    }
}
