using System;
using CringeBank.Domain.Auth.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Auth;

public sealed class AuthUserBlockConfiguration : IEntityTypeConfiguration<AuthUserBlock>
{
    public void Configure(EntityTypeBuilder<AuthUserBlock> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("UserBlocks", "auth");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.BlockerUserId)
            .HasColumnName("blocker_user_id")
            .IsRequired();

        builder.Property(x => x.BlockedUserId)
            .HasColumnName("blocked_user_id")
            .IsRequired();

        builder.Property(x => x.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("datetime2(3)")
            .HasDefaultValueSql("SYSUTCDATETIME()")
            .IsRequired();

        builder.HasOne(x => x.Blocker)
            .WithMany(x => x.BlocksInitiated)
            .HasForeignKey(x => x.BlockerUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.Blocked)
            .WithMany(x => x.BlocksReceived)
            .HasForeignKey(x => x.BlockedUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(x => new { x.BlockerUserId, x.BlockedUserId })
            .IsUnique()
            .HasDatabaseName("UX_UserBlocks_Blocker_Blocked");

        builder.HasIndex(x => x.BlockedUserId)
            .HasDatabaseName("IX_UserBlocks_BlockedUserId");
    }
}
