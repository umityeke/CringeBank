using System;
using CringeBank.Application.Users.Queries;

namespace CringeBank.Api.Profiles;

internal static class PublicProfileMapper
{
    public static PublicProfileResponse Map(UserProfileResult profile)
    {
        ArgumentNullException.ThrowIfNull(profile);

        return new PublicProfileResponse(
            profile.PublicId,
            profile.Username,
            profile.Status.ToString(),
            profile.DisplayName,
            profile.Bio,
            profile.Verified,
            profile.AvatarUrl,
            profile.BannerUrl,
            profile.Location,
            profile.Website,
            profile.CreatedAt,
            profile.UpdatedAt,
            profile.LastLoginAt);
    }
}
