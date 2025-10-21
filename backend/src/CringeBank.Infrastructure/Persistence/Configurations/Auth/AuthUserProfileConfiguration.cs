using System;
using CringeBank.Domain.Auth.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Auth;

public sealed class AuthUserProfileConfiguration : IEntityTypeConfiguration<AuthUserProfile>
{
    public void Configure(EntityTypeBuilder<AuthUserProfile> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("UserProfiles", "auth");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.UserId)
            .HasColumnName("user_id")
            .IsRequired();

        builder.Property(x => x.DisplayName)
            .HasColumnName("display_name")
            .HasMaxLength(128);

        builder.Property(x => x.Bio)
            .HasColumnName("bio")
            .HasMaxLength(512);

        builder.Property(x => x.AvatarUrl)
            .HasColumnName("avatar_url")
            .HasMaxLength(512);

        builder.Property(x => x.BannerUrl)
            .HasColumnName("banner_url")
            .HasMaxLength(512);

        builder.Property(x => x.Verified)
            .HasColumnName("verified")
            .HasDefaultValue(false)
            .IsRequired();

        builder.Property(x => x.Location)
            .HasColumnName("location")
            .HasMaxLength(128);

        builder.Property(x => x.Website)
            .HasColumnName("website")
            .HasMaxLength(256);

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

        builder.HasOne(x => x.User)
            .WithOne(x => x.Profile)
            .HasForeignKey<AuthUserProfile>(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => x.UserId)
            .IsUnique()
            .HasDatabaseName("UK_UserProfiles_UserId");
    }
}
