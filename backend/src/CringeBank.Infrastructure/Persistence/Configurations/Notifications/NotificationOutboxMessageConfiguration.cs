using System;
using CringeBank.Domain.Notify.Entities;
using CringeBank.Domain.Notify.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Notifications;

public sealed class NotificationOutboxMessageConfiguration : IEntityTypeConfiguration<NotificationOutboxMessage>
{
    public void Configure(EntityTypeBuilder<NotificationOutboxMessage> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Outbox", "notify");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.NotificationId)
            .HasColumnName("notification_id")
            .IsRequired();

        builder.Property(x => x.Channel)
            .HasColumnName("channel")
            .HasConversion<byte>()
            .IsRequired();

        builder.Property(x => x.Topic)
            .HasColumnName("topic")
            .HasMaxLength(128)
            .IsRequired();

        builder.Property(x => x.PayloadJson)
            .HasColumnName("payload_json")
            .HasColumnType("nvarchar(max)")
            .IsRequired();

        builder.Property(x => x.Status)
            .HasColumnName("status")
            .HasConversion<byte>()
            .HasDefaultValue(NotificationOutboxStatus.Pending)
            .IsRequired();

        builder.Property(x => x.RetryCount)
            .HasColumnName("retry_count")
            .HasDefaultValue(0)
            .IsRequired();

        builder.Property(x => x.CreatedAtUtc)
            .HasColumnName("created_at_utc")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.Property(x => x.ProcessedAtUtc)
            .HasColumnName("processed_at_utc")
            .HasColumnType("datetime2(3)");

        builder.HasIndex(x => new { x.Status, x.CreatedAtUtc })
            .HasDatabaseName("IX_NotifyOutbox_Status_CreatedAt");

        builder.HasOne(x => x.Notification)
            .WithMany(x => x.OutboxMessages)
            .HasForeignKey(x => x.NotificationId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
