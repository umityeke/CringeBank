namespace CringeBank.Api.Profiles;

public sealed record UpdateAuthUserProfileRequest(
    string? DisplayName,
    string? Bio,
    string? Website,
    string? AvatarUrl,
    string? BannerUrl,
    string? Location);
