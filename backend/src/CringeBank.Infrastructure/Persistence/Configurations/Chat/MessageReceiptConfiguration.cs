using System;
using CringeBank.Domain.Chat.Entities;
using CringeBank.Domain.Chat.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Chat;

public sealed class MessageReceiptConfiguration : IEntityTypeConfiguration<MessageReceipt>
{
    public void Configure(EntityTypeBuilder<MessageReceipt> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("MessageReceipts", "chat");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.MessageId)
            .HasColumnName("message_id")
            .IsRequired();

        builder.Property(x => x.UserId)
            .HasColumnName("user_id")
            .IsRequired();

        builder.Property(x => x.ReceiptType)
            .HasColumnName("receipt_type")
            .HasConversion<byte>()
            .HasDefaultValue(MessageReceiptType.Delivered)
            .IsRequired();

        builder.Property(x => x.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.HasOne(x => x.Message)
            .WithMany(x => x.Receipts)
            .HasForeignKey(x => x.MessageId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => new { x.MessageId, x.UserId, x.ReceiptType })
            .IsUnique()
            .HasDatabaseName("IX_MessageReceipts_message_id_user_id_receipt_type");

        builder.HasIndex(x => x.UserId)
            .HasDatabaseName("IX_MessageReceipts_user_id");
    }
}
