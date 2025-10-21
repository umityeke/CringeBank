using System;
using CringeBank.Domain.Chat.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Chat;

public sealed class MessageConfiguration : IEntityTypeConfiguration<Message>
{
    public void Configure(EntityTypeBuilder<Message> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Messages", "chat");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.ConversationId)
            .HasColumnName("conversation_id")
            .IsRequired();

        builder.Property(x => x.SenderUserId)
            .HasColumnName("sender_user_id")
            .IsRequired();

        builder.Property(x => x.Body)
            .HasColumnName("body")
            .HasMaxLength(2000);

        builder.Property(x => x.DeletedForAll)
            .HasColumnName("deleted_for_all")
            .HasColumnType("bit")
            .HasDefaultValue(false)
            .IsRequired();

        builder.Property(x => x.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.Property(x => x.EditedAt)
            .HasColumnName("edited_at")
            .HasColumnType("datetime2(3)");

        builder.HasOne(x => x.Conversation)
            .WithMany(x => x.Messages)
            .HasForeignKey(x => x.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.Sender)
            .WithMany()
            .HasForeignKey(x => x.SenderUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(x => new { x.ConversationId, x.CreatedAt, x.Id })
            .HasDatabaseName("IX_Messages_conversation_id_created_at_id");

        builder.HasIndex(x => x.SenderUserId)
            .HasDatabaseName("IX_Messages_sender_user_id");
    }
}
