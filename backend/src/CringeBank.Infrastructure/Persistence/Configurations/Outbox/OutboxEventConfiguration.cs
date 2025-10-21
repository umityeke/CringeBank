using System;
using CringeBank.Domain.Outbox.Entities;
using CringeBank.Domain.Outbox.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Outbox;

public sealed class OutboxEventConfiguration : IEntityTypeConfiguration<OutboxEvent>
{
    public void Configure(EntityTypeBuilder<OutboxEvent> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Events", "outbox");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.Topic)
            .HasColumnName("topic")
            .HasMaxLength(128)
            .IsRequired();

        builder.Property(x => x.Payload)
            .HasColumnName("payload")
            .HasColumnType("nvarchar(max)")
            .IsRequired();

        builder.Property(x => x.Status)
            .HasColumnName("status")
            .HasConversion<byte>()
            .HasDefaultValue(OutboxEventStatus.Pending)
            .IsRequired();

        builder.Property(x => x.Retries)
            .HasColumnName("retries")
            .HasDefaultValue(0)
            .IsRequired();

        builder.Property(x => x.CreatedAtUtc)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.Property(x => x.ProcessedAtUtc)
            .HasColumnName("processed_at")
            .HasColumnType("datetime2(3)");

        builder.HasIndex(x => x.Status)
            .HasDatabaseName("IX_OutboxEvents_Status");

        builder.HasIndex(x => new { x.Status, x.CreatedAtUtc })
            .HasDatabaseName("IX_OutboxEvents_Status_CreatedAt");
    }
}
