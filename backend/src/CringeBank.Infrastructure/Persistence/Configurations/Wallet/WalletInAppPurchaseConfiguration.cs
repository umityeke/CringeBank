using System;
using CringeBank.Domain.Wallet.Entities;
using CringeBank.Domain.Wallet.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Wallets;

public sealed class WalletInAppPurchaseConfiguration : IEntityTypeConfiguration<WalletInAppPurchase>
{
    public void Configure(EntityTypeBuilder<WalletInAppPurchase> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("InAppPurchases", "wallet");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.AccountId)
            .HasColumnName("account_id")
            .IsRequired();

        builder.Property(x => x.Platform)
            .HasColumnName("platform")
            .HasMaxLength(32)
            .IsRequired();

        builder.Property(x => x.Receipt)
            .HasColumnName("receipt")
            .HasColumnType("nvarchar(max)")
            .IsRequired();

        builder.Property(x => x.Status)
            .HasColumnName("status")
            .HasConversion<byte>()
            .HasDefaultValue(WalletInAppPurchaseStatus.Pending)
            .IsRequired();

        builder.Property(x => x.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.Property(x => x.ValidatedAt)
            .HasColumnName("validated_at")
            .HasColumnType("datetime2(3)");

        builder.HasOne(x => x.Account)
            .WithMany(x => x.InAppPurchases)
            .HasForeignKey(x => x.AccountId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => new { x.AccountId, x.Status })
            .HasDatabaseName("IX_InAppPurchases_account_id_status");
    }
}
