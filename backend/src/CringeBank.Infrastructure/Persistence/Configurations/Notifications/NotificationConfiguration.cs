using System;
using CringeBank.Domain.Notify.Entities;
using CringeBank.Domain.Notify.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Notifications;

public sealed class NotificationConfiguration : IEntityTypeConfiguration<Notification>
{
    public void Configure(EntityTypeBuilder<Notification> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Notifications", "notify");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.PublicId)
            .HasColumnName("public_id")
            .HasDefaultValueSql("NEWSEQUENTIALID()")
            .IsRequired();

        builder.HasIndex(x => x.PublicId)
            .IsUnique();

        builder.Property(x => x.RecipientUserId)
            .HasColumnName("recipient_user_id")
            .IsRequired();

        builder.Property(x => x.SenderUserId)
            .HasColumnName("sender_user_id");

        builder.Property(x => x.Type)
            .HasColumnName("type")
            .HasConversion<byte>()
            .HasDefaultValue(NotificationType.System)
            .IsRequired();

        builder.Property(x => x.Title)
            .HasColumnName("title")
            .HasMaxLength(200)
            .IsRequired();

        builder.Property(x => x.Body)
            .HasColumnName("body")
            .HasMaxLength(512);

        builder.Property(x => x.ActionUrl)
            .HasColumnName("action_url")
            .HasMaxLength(512);

        builder.Property(x => x.ImageUrl)
            .HasColumnName("image_url")
            .HasMaxLength(512);

        builder.Property(x => x.PayloadJson)
            .HasColumnName("payload_json")
            .HasColumnType("nvarchar(max)")
            .HasDefaultValue("{}")
            .IsRequired();

        builder.Property(x => x.IsRead)
            .HasColumnName("is_read")
            .HasDefaultValue(false)
            .IsRequired();

        builder.Property(x => x.CreatedAtUtc)
            .HasColumnName("created_at_utc")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.Property(x => x.ReadAtUtc)
            .HasColumnName("read_at_utc")
            .HasColumnType("datetime2(3)");

        builder.HasIndex(x => new { x.RecipientUserId, x.CreatedAtUtc })
            .HasDatabaseName("IX_Notifications_Recipient_CreatedAt");

        builder.HasIndex(x => new { x.RecipientUserId, x.IsRead, x.CreatedAtUtc })
            .HasDatabaseName("IX_Notifications_ReadState");

        builder.HasOne(x => x.Recipient)
            .WithMany()
            .HasForeignKey(x => x.RecipientUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.Sender)
            .WithMany()
            .HasForeignKey(x => x.SenderUserId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.Navigation(x => x.OutboxMessages).AutoInclude(false);
    }
}
