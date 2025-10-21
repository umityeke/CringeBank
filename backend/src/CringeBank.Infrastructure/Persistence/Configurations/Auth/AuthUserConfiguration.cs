using System;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Auth.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Auth;

public sealed class AuthUserConfiguration : IEntityTypeConfiguration<AuthUser>
{
    public void Configure(EntityTypeBuilder<AuthUser> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Users", "auth");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.PublicId)
            .HasColumnName("public_id")
            .HasDefaultValueSql("NEWSEQUENTIALID()");

        builder.Property(x => x.Email)
            .HasColumnName("email")
            .HasMaxLength(256)
            .IsRequired();

        builder.Property(x => x.EmailNormalized)
            .HasColumnName("email_normalized")
            .HasMaxLength(256)
            .IsRequired();

        builder.Property(x => x.Username)
            .HasColumnName("username")
            .HasMaxLength(64)
            .IsRequired();

        builder.Property(x => x.UsernameNormalized)
            .HasColumnName("username_normalized")
            .HasMaxLength(64)
            .IsRequired();

        builder.Property(x => x.PasswordHash)
            .HasColumnName("password_hash")
            .HasColumnType("varbinary(max)");

        builder.Property(x => x.PasswordSalt)
            .HasColumnName("password_salt")
            .HasColumnType("varbinary(128)");

        builder.Property(x => x.AuthProvider)
            .HasColumnName("auth_provider")
            .HasMaxLength(32)
            .IsRequired()
            .HasDefaultValue("sql");

        builder.Property(x => x.Phone)
            .HasColumnName("phone")
            .HasMaxLength(32);

        builder.Property(x => x.Status)
            .HasColumnName("status")
            .HasConversion<byte>()
            .HasDefaultValue(AuthUserStatus.Active)
            .IsRequired();

        builder.Property(x => x.LastLoginAt)
            .HasColumnName("last_login_at")
            .HasColumnType("datetime2(3)");

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

        builder.HasIndex(x => x.Email)
            .IsUnique();

        builder.HasIndex(x => x.EmailNormalized)
            .IsUnique()
            .HasDatabaseName("IX_Users_EmailNormalized");

        builder.HasIndex(x => x.Username)
            .IsUnique();

        builder.HasIndex(x => x.UsernameNormalized)
            .IsUnique()
            .HasDatabaseName("IX_Users_UsernameNormalized");

        builder.HasMany(x => x.BlocksInitiated)
            .WithOne(x => x.Blocker)
            .HasForeignKey(x => x.BlockerUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(x => x.BlocksReceived)
            .WithOne(x => x.Blocked)
            .HasForeignKey(x => x.BlockedUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(x => x.Followers)
            .WithOne(x => x.Followee)
            .HasForeignKey(x => x.FolloweeUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(x => x.Following)
            .WithOne(x => x.Follower)
            .HasForeignKey(x => x.FollowerUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(x => x.DeviceTokens)
            .WithOne(x => x.User)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(x => x.UserRoles)
            .WithOne(x => x.User)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(x => x.Posts)
            .WithOne(x => x.Author)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(x => x.PostLikes)
            .WithOne(x => x.User)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(x => x.PostComments)
            .WithOne(x => x.User)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(x => x.CommentLikes)
            .WithOne(x => x.User)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(x => x.PostSaves)
            .WithOne(x => x.User)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
