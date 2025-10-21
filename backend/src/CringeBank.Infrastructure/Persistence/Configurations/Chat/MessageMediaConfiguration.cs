using System;
using CringeBank.Domain.Chat.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Chat;

public sealed class MessageMediaConfiguration : IEntityTypeConfiguration<MessageMedia>
{
    public void Configure(EntityTypeBuilder<MessageMedia> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("MessageMedia", "chat");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.MessageId)
            .HasColumnName("message_id")
            .IsRequired();

        builder.Property(x => x.Url)
            .HasColumnName("url")
            .HasMaxLength(512)
            .IsRequired();

        builder.Property(x => x.Mime)
            .HasColumnName("mime")
            .HasMaxLength(64);

        builder.Property(x => x.Width)
            .HasColumnName("width");

        builder.Property(x => x.Height)
            .HasColumnName("height");

        builder.HasOne(x => x.Message)
            .WithMany(x => x.Media)
            .HasForeignKey(x => x.MessageId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => x.MessageId)
            .HasDatabaseName("IX_MessageMedia_message_id");
    }
}
