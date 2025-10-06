using System;
using CringeBank.Domain.Entities;
using CringeBank.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations;

public sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Users");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.FirebaseUid)
            .IsRequired()
            .HasMaxLength(128);

        builder.Property(x => x.Email)
            .IsRequired()
            .HasMaxLength(256);

        builder.Property(x => x.PhoneNumber)
            .HasMaxLength(32);

        builder.Property(x => x.DisplayName)
            .IsRequired()
            .HasMaxLength(256);

        builder.Property(x => x.ProfileImageUrl)
            .HasMaxLength(512);

        builder.Property(x => x.ClaimsVersion)
            .IsRequired();

        builder.Property(x => x.EmailVerified)
            .IsRequired();

        builder.Property(x => x.IsDisabled)
            .IsRequired();

        builder.Property(x => x.Status)
            .HasConversion<string>()
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(x => x.DisabledAtUtc)
            .HasColumnType("datetimeoffset");

        builder.Property(x => x.DeletedAtUtc)
            .HasColumnType("datetimeoffset");

        builder.Property(x => x.LastLoginAtUtc)
            .HasColumnType("datetimeoffset");

        builder.Property(x => x.LastSyncedAtUtc)
            .HasColumnType("datetimeoffset");

        builder.Property(x => x.CreatedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired();

        builder.Property(x => x.UpdatedAtUtc)
            .HasColumnType("datetimeoffset")
            .IsRequired();

        builder.Property(x => x.LastSeenAppVersion)
            .HasMaxLength(64);

        builder.HasIndex(x => x.FirebaseUid)
            .IsUnique();

        builder.HasIndex(x => x.Email)
            .HasFilter("[DeletedAtUtc] IS NULL")
            .IsUnique();

        builder.HasIndex(x => new { x.Status, x.LastSyncedAtUtc });
    }
}
