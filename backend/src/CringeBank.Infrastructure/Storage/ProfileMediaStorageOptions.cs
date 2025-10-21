namespace CringeBank.Infrastructure.Storage;

public sealed class ProfileMediaStorageOptions
{
    public string? ConnectionString { get; set; }

    public string? ContainerName { get; set; }

    public string AvatarPrefix { get; set; } = "avatars";

    public string BannerPrefix { get; set; } = "banners";

    public int UploadExpiryMinutes { get; set; } = 15;
}
