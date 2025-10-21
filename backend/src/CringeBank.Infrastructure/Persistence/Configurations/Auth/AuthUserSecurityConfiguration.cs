using System;
using CringeBank.Domain.Auth.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Auth;

public sealed class AuthUserSecurityConfiguration : IEntityTypeConfiguration<AuthUserSecurity>
{
    public void Configure(EntityTypeBuilder<AuthUserSecurity> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("UserSecurity", "auth");

        builder.HasKey(x => x.UserId);

        builder.Property(x => x.UserId)
            .HasColumnName("user_id")
            .ValueGeneratedNever();

        builder.Property(x => x.OtpSecret)
            .HasColumnName("otp_secret")
            .HasColumnType("varbinary(256)");

        builder.Property(x => x.OtpEnabled)
            .HasColumnName("otp_enabled")
            .HasDefaultValue(false)
            .IsRequired();

        builder.Property(x => x.MagicCodeHash)
            .HasColumnName("magic_code_hash")
            .HasColumnType("varbinary(256)");

        builder.Property(x => x.MagicCodeExpiresAt)
            .HasColumnName("magic_code_expires_at")
            .HasColumnType("datetime2(3)");

        builder.Property(x => x.RefreshTokenHash)
            .HasColumnName("refresh_token_hash")
            .HasColumnType("varbinary(256)");

        builder.Property(x => x.RefreshTokenExpiresAt)
            .HasColumnName("refresh_token_expires_at")
            .HasColumnType("datetime2(3)");

        builder.Property(x => x.LastPasswordResetAt)
            .HasColumnName("last_password_reset_at")
            .HasColumnType("datetime2(3)");

        builder.HasOne(x => x.User)
            .WithOne(x => x.Security)
            .HasForeignKey<AuthUserSecurity>(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
