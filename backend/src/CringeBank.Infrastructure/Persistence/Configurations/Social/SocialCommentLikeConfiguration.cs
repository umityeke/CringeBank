using System;
using CringeBank.Domain.Social.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Social;

public sealed class SocialCommentLikeConfiguration : IEntityTypeConfiguration<SocialCommentLike>
{
    public void Configure(EntityTypeBuilder<SocialCommentLike> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("CommentLikes", "social");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.CommentId)
            .HasColumnName("comment_id")
            .IsRequired();

        builder.Property(x => x.UserId)
            .HasColumnName("user_id")
            .IsRequired();

        builder.Property(x => x.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.HasOne(x => x.Comment)
            .WithMany(x => x.Likes)
            .HasForeignKey(x => x.CommentId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.User)
            .WithMany(x => x.CommentLikes)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(x => new { x.CommentId, x.UserId })
            .IsUnique()
            .HasDatabaseName("UX_CommentLikes_Comment_User");
    }
}
