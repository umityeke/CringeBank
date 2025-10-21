using System;
using CringeBank.Domain.Wallet.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Wallets;

public sealed class WalletAccountConfiguration : IEntityTypeConfiguration<WalletAccount>
{
    public void Configure(EntityTypeBuilder<WalletAccount> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Accounts", "wallet");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.UserId)
            .HasColumnName("user_id")
            .IsRequired();

        builder.Property(x => x.Balance)
            .HasColumnName("balance")
            .HasColumnType("decimal(18,2)")
            .HasDefaultValue(0m)
            .IsRequired();

        builder.Property(x => x.Currency)
            .HasColumnName("currency")
            .HasMaxLength(3)
            .HasDefaultValue("CG")
            .IsRequired();

        builder.Property(x => x.UpdatedAt)
            .HasColumnName("updated_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(x => x.Transactions)
            .WithOne(x => x.Account)
            .HasForeignKey(x => x.AccountId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(x => x.OutgoingTransfers)
            .WithOne(x => x.FromAccount)
            .HasForeignKey(x => x.FromAccountId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasMany(x => x.IncomingTransfers)
            .WithOne(x => x.ToAccount)
            .HasForeignKey(x => x.ToAccountId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasMany(x => x.InAppPurchases)
            .WithOne(x => x.Account)
            .HasForeignKey(x => x.AccountId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => x.UserId)
            .IsUnique()
            .HasDatabaseName("UX_Accounts_user_id");
    }
}
