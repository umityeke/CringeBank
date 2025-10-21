using System;
using CringeBank.Domain.Social.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Social;

public sealed class SocialPostMediaConfiguration : IEntityTypeConfiguration<SocialPostMedia>
{
    public void Configure(EntityTypeBuilder<SocialPostMedia> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("PostMedia", "social");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd();

        builder.Property(x => x.PostId)
            .HasColumnName("post_id")
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

        builder.Property(x => x.OrderIndex)
            .HasColumnName("order_index")
            .HasDefaultValue((byte)0)
            .IsRequired();

        builder.HasOne(x => x.Post)
            .WithMany(x => x.Media)
            .HasForeignKey(x => x.PostId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
