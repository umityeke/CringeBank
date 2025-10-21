using System;
using CringeBank.Domain.Wallet.Entities;
using CringeBank.Domain.Wallet.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Wallets;

public sealed class WalletTransferAuditConfiguration : IEntityTypeConfiguration<WalletTransferAudit>
{
    public void Configure(EntityTypeBuilder<WalletTransferAudit> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("TransferAudits", "wallet");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.FromAccountId)
            .HasColumnName("from_account_id");

        builder.Property(x => x.ToAccountId)
            .HasColumnName("to_account_id");

        builder.Property(x => x.Amount)
            .HasColumnName("amount")
            .HasColumnType("decimal(18,2)")
            .IsRequired();

        builder.Property(x => x.Status)
            .HasColumnName("status")
            .HasConversion<byte>()
            .IsRequired();

        builder.Property(x => x.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.HasOne(x => x.FromAccount)
            .WithMany(x => x.OutgoingTransfers)
            .HasForeignKey(x => x.FromAccountId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.ToAccount)
            .WithMany(x => x.IncomingTransfers)
            .HasForeignKey(x => x.ToAccountId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(x => x.CreatedAt)
            .HasDatabaseName("IX_TransferAudits_created_at");
    }
}
