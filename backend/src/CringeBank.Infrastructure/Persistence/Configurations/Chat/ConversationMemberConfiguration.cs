using System;
using CringeBank.Domain.Chat.Entities;
using CringeBank.Domain.Chat.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Chat;

public sealed class ConversationMemberConfiguration : IEntityTypeConfiguration<ConversationMember>
{
    public void Configure(EntityTypeBuilder<ConversationMember> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("ConversationMembers", "chat");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.ConversationId)
            .HasColumnName("conversation_id")
            .IsRequired();

        builder.Property(x => x.UserId)
            .HasColumnName("user_id")
            .IsRequired();

        builder.Property(x => x.Role)
            .HasColumnName("role")
            .HasConversion<byte>()
            .HasDefaultValue(ConversationMemberRole.Participant)
            .IsRequired();

        builder.Property(x => x.JoinedAt)
            .HasColumnName("joined_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.Property(x => x.LastReadMessageId)
            .HasColumnName("last_read_message_id");

        builder.Property(x => x.LastReadAt)
            .HasColumnName("last_read_at")
            .HasColumnType("datetime2(3)");

        builder.HasOne(x => x.Conversation)
            .WithMany(x => x.Members)
            .HasForeignKey(x => x.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => new { x.ConversationId, x.UserId })
            .IsUnique();
    }
}
