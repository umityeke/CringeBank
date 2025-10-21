using System;
using CringeBank.Domain.Auth.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Auth;

public sealed class AuthFollowConfiguration : IEntityTypeConfiguration<AuthFollow>
{
    public void Configure(EntityTypeBuilder<AuthFollow> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Follows", "auth");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.FollowerUserId)
            .HasColumnName("follower_user_id")
            .IsRequired();

        builder.Property(x => x.FolloweeUserId)
            .HasColumnName("followee_user_id")
            .IsRequired();

        builder.Property(x => x.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.HasOne(x => x.Follower)
            .WithMany(x => x.Following)
            .HasForeignKey(x => x.FollowerUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.Followee)
            .WithMany(x => x.Followers)
            .HasForeignKey(x => x.FolloweeUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(x => new { x.FollowerUserId, x.FolloweeUserId })
            .IsUnique()
            .HasDatabaseName("UX_Follows_Follower_Followee");

        builder.HasIndex(x => new { x.FolloweeUserId, x.CreatedAt })
            .HasDatabaseName("IX_Follows_Followee_CreatedAt");
    }
}
