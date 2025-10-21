using System;
using CringeBank.Domain.Wallet.Entities;
using CringeBank.Domain.Wallet.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Wallets;

public sealed class WalletTransactionConfiguration : IEntityTypeConfiguration<WalletTransaction>
{
    public void Configure(EntityTypeBuilder<WalletTransaction> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Transactions", "wallet");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.AccountId)
            .HasColumnName("account_id")
            .IsRequired();

        builder.Property(x => x.ExternalId)
            .HasColumnName("external_id")
            .HasDefaultValueSql("NEWSEQUENTIALID()")
            .IsRequired();

        builder.Property(x => x.Type)
            .HasColumnName("type")
            .HasConversion<byte>()
            .IsRequired();

        builder.Property(x => x.Amount)
            .HasColumnName("amount")
            .HasColumnType("decimal(18,2)")
            .IsRequired();

        builder.Property(x => x.BalanceAfter)
            .HasColumnName("balance_after")
            .HasColumnType("decimal(18,2)")
            .IsRequired();

        builder.Property(x => x.Reference)
            .HasColumnName("reference")
            .HasMaxLength(128);

        builder.Property(x => x.Metadata)
            .HasColumnName("metadata")
            .HasColumnType("nvarchar(max)");

        builder.Property(x => x.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.HasOne(x => x.Account)
            .WithMany(x => x.Transactions)
            .HasForeignKey(x => x.AccountId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => new { x.AccountId, x.CreatedAt })
            .HasDatabaseName("IX_Transactions_account_id_created_at");
    }
}
