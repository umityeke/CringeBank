using System;
using CringeBank.Domain.Auth.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Auth;

public sealed class AuthDeviceTokenConfiguration : IEntityTypeConfiguration<AuthDeviceToken>
{
    public void Configure(EntityTypeBuilder<AuthDeviceToken> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("DeviceTokens", "auth");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.UserId)
            .HasColumnName("user_id")
            .IsRequired();

        builder.Property(x => x.Platform)
            .HasColumnName("platform")
            .HasMaxLength(32)
            .IsRequired();

        builder.Property(x => x.Token)
            .HasColumnName("token")
            .HasMaxLength(512)
            .IsRequired();

        builder.Property(x => x.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.Property(x => x.LastUsedAt)
            .HasColumnName("last_used_at")
            .HasColumnType("datetime2(3)");

        builder.HasOne(x => x.User)
            .WithMany(x => x.DeviceTokens)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => new { x.UserId, x.Token })
            .IsUnique()
            .HasDatabaseName("UX_DeviceTokens_User_Token");
    }
}
