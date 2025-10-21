using System;
using CringeBank.Domain.Social.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CringeBank.Infrastructure.Persistence.Configurations.Social;

public sealed class SocialPostTagConfiguration : IEntityTypeConfiguration<SocialPostTag>
{
    public void Configure(EntityTypeBuilder<SocialPostTag> builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ToTable("PostTags", "social");

        builder.HasKey(x => new { x.PostId, x.TagId });

        builder.Property(x => x.PostId)
            .HasColumnName("post_id")
            .IsRequired();

        builder.Property(x => x.TagId)
            .HasColumnName("tag_id")
            .IsRequired();

        builder.HasOne(x => x.Post)
            .WithMany(x => x.Tags)
            .HasForeignKey(x => x.PostId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.Tag)
            .WithMany(x => x.PostTags)
            .HasForeignKey(x => x.TagId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
