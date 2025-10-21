using System;
using DisplayNameValue = CringeBank.Domain.ValueObjects.DisplayName;
using ProfileBioValue = CringeBank.Domain.ValueObjects.ProfileBio;
using WebsiteUrlValue = CringeBank.Domain.ValueObjects.WebsiteUrl;

namespace CringeBank.Domain.Auth.Entities;

public sealed partial class AuthUserProfile
{
    public static AuthUserProfile Create(long userId, DisplayNameValue displayName, ProfileBioValue bio, WebsiteUrlValue website, string? avatarUrl, string? bannerUrl, bool verified, string? location)
    {
        ArgumentNullException.ThrowIfNull(displayName);
        ArgumentNullException.ThrowIfNull(bio);
        ArgumentNullException.ThrowIfNull(website);

        var utcNow = DateTime.UtcNow;

        return new AuthUserProfile
        {
            UserId = userId,
            DisplayName = displayName.Value,
            Bio = bio.Value,
            Website = website.Value,
            AvatarUrl = avatarUrl,
            BannerUrl = bannerUrl,
            Verified = verified,
            Location = location,
            CreatedAt = utcNow,
            UpdatedAt = utcNow
        };
    }

    public DisplayNameValue DisplayNameValueObject => DisplayNameValue.Create(DisplayName);

    public ProfileBioValue BioValueObject => ProfileBioValue.Create(Bio);

    public WebsiteUrlValue WebsiteValueObject => WebsiteUrlValue.Create(Website);

    public void Update(DisplayNameValue displayName, ProfileBioValue bio, WebsiteUrlValue website, string? avatarUrl, string? bannerUrl, bool verified, string? location)
    {
        ArgumentNullException.ThrowIfNull(displayName);
        ArgumentNullException.ThrowIfNull(bio);
        ArgumentNullException.ThrowIfNull(website);

        DisplayName = displayName.Value;
        Bio = bio.Value;
        Website = website.Value;
        AvatarUrl = avatarUrl;
        BannerUrl = bannerUrl;
        Verified = verified;
        Location = location;
        Touch();
    }

    public void Touch(DateTime? utcNow = null)
    {
        UpdatedAt = (utcNow ?? DateTime.UtcNow).ToUniversalTime();
    }
}
