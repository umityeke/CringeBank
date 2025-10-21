using System;
using CringeBank.Domain.Auth.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Auth;

public sealed class AuthRoleConfiguration : IEntityTypeConfiguration<AuthRole>
{
    public void Configure(EntityTypeBuilder<AuthRole> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("Roles", "auth");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.Name)
            .HasColumnName("name")
            .HasMaxLength(64)
            .IsRequired();

        builder.Property(x => x.Description)
            .HasColumnName("description")
            .HasMaxLength(256);

        builder.HasMany(x => x.UserRoles)
            .WithOne(x => x.Role)
            .HasForeignKey(x => x.RoleId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(x => x.Name)
            .IsUnique();
    }
}
