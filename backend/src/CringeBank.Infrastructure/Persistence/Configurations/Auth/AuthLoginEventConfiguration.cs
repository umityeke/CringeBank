using System;
using CringeBank.Domain.Auth.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Auth;

public sealed class AuthLoginEventConfiguration : IEntityTypeConfiguration<AuthLoginEvent>
{
    public void Configure(EntityTypeBuilder<AuthLoginEvent> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("LoginEvents", "auth");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.UserId)
            .HasColumnName("user_id");

        builder.Property(x => x.Identifier)
            .HasColumnName("identifier")
            .HasMaxLength(256)
            .IsRequired();

        builder.Property(x => x.EventAtUtc)
            .HasColumnName("event_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.Property(x => x.Source)
            .HasColumnName("source")
            .HasMaxLength(64)
            .HasDefaultValue("unknown")
            .IsRequired();

        builder.Property(x => x.Channel)
            .HasColumnName("channel")
            .HasMaxLength(32)
            .HasDefaultValue("login")
            .IsRequired();

        builder.Property(x => x.Result)
            .HasColumnName("result")
            .HasMaxLength(16)
            .HasDefaultValue("success")
            .IsRequired();

        builder.Property(x => x.DeviceIdHash)
            .HasColumnName("device_id_hash")
            .HasMaxLength(128);

        builder.Property(x => x.IpHash)
            .HasColumnName("ip_hash")
            .HasMaxLength(128);

        builder.Property(x => x.UserAgent)
            .HasColumnName("user_agent")
            .HasMaxLength(512);

        builder.Property(x => x.Locale)
            .HasColumnName("locale")
            .HasMaxLength(16);

        builder.Property(x => x.TimeZone)
            .HasColumnName("time_zone")
            .HasMaxLength(64);

        builder.Property(x => x.IsTrustedDevice)
            .HasColumnName("is_trusted_device")
            .HasDefaultValue(false)
            .IsRequired();

        builder.Property(x => x.RememberMe)
            .HasColumnName("remember_me")
            .HasDefaultValue(false)
            .IsRequired();

        builder.Property(x => x.RequiresDeviceVerification)
            .HasColumnName("requires_device_verification")
            .HasDefaultValue(false)
            .IsRequired();

        builder.Property(x => x.CreatedAtUtc)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.HasIndex(x => new { x.UserId, x.EventAtUtc })
            .HasDatabaseName("IX_LoginEvents_User_EventAt");

        builder.HasOne(x => x.User)
            .WithMany(x => x.LoginEvents)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.SetNull);
    }
}