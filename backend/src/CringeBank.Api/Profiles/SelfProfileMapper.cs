using System;
using CringeBank.Application.Users.Queries;

namespace CringeBank.Api.Profiles;

internal static class SelfProfileMapper
{
    public static SelfProfileResponse Map(UserProfileResult profile)
    {
        ArgumentNullException.ThrowIfNull(profile);

        return new SelfProfileResponse(
            profile.PublicId,
            profile.Email,
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
