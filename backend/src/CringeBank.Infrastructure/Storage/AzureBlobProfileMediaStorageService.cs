using System;
using System.Globalization;
using System.Threading;
using System.Threading.Tasks;
using Azure.Storage.Blobs;
using Azure.Storage.Sas;
using CringeBank.Application.Users;
using Microsoft.Extensions.Options;

namespace CringeBank.Infrastructure.Storage;

public sealed class AzureBlobProfileMediaStorageService : IProfileMediaStorageService
{
    private const string StorageNotConfiguredCode = "storage_not_configured";
    private readonly ProfileMediaStorageOptions _options;

    public AzureBlobProfileMediaStorageService(IOptions<ProfileMediaStorageOptions> options)
    {
        _options = options?.Value ?? throw new ArgumentNullException(nameof(options));
    }

    public async Task<ProfileMediaUploadToken> CreateUploadTokenAsync(Guid userPublicId, ProfileMediaType mediaType, string contentType, CancellationToken cancellationToken = default)
    {
        if (userPublicId == Guid.Empty)
        {
            throw new InvalidOperationException("invalid_user_identifier");
        }

        if (string.IsNullOrWhiteSpace(contentType))
        {
            throw new InvalidOperationException("invalid_content_type");
        }

        if (string.IsNullOrWhiteSpace(_options.ConnectionString) || string.IsNullOrWhiteSpace(_options.ContainerName))
        {
            throw new InvalidOperationException(StorageNotConfiguredCode);
        }

        var prefix = mediaType switch
        {
            ProfileMediaType.Avatar => NormalizeSegment(_options.AvatarPrefix, "avatars"),
            ProfileMediaType.Banner => NormalizeSegment(_options.BannerPrefix, "banners"),
            _ => throw new InvalidOperationException("unsupported_media_type")
        };

        var blobServiceClient = new BlobServiceClient(_options.ConnectionString);
        var containerClient = blobServiceClient.GetBlobContainerClient(_options.ContainerName);
        await containerClient.CreateIfNotExistsAsync(cancellationToken: cancellationToken).ConfigureAwait(false);

        var normalizedContentType = contentType.Trim();
        var extension = ResolveExtension(normalizedContentType);
        var timestamp = DateTimeOffset.UtcNow;
        var blobName = string.Format(
            CultureInfo.InvariantCulture,
            "{0}/{1:N}/{2:yyyy/MM/dd}/{3:N}{4}",
            prefix,
            userPublicId,
            timestamp,
            Guid.NewGuid(),
            extension);

        var blobClient = containerClient.GetBlobClient(blobName);

        if (!blobClient.CanGenerateSasUri)
        {
            throw new InvalidOperationException(StorageNotConfiguredCode);
        }

        var expires = timestamp.AddMinutes(Math.Max(1, _options.UploadExpiryMinutes));
        var sasBuilder = new BlobSasBuilder
        {
            BlobContainerName = containerClient.Name,
            BlobName = blobName,
            Resource = "b",
            StartsOn = timestamp.AddMinutes(-5),
            ExpiresOn = expires,
            ContentType = normalizedContentType
        };

        sasBuilder.SetPermissions(BlobSasPermissions.Create | BlobSasPermissions.Add | BlobSasPermissions.Write);

        var uploadUri = blobClient.GenerateSasUri(sasBuilder);

        return new ProfileMediaUploadToken(uploadUri, blobClient.Uri, expires, blobName, normalizedContentType);
    }

    private static string NormalizeSegment(string? value, string fallback)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return fallback;
        }

        var trimmed = value.Trim('/');
        return trimmed.Length == 0 ? fallback : trimmed;
    }

    private static string ResolveExtension(string contentType)
    {
        return contentType.ToLowerInvariant() switch
        {
            "image/jpeg" or "image/jpg" => ".jpg",
            "image/png" => ".png",
            "image/gif" => ".gif",
            "image/webp" => ".webp",
            _ => string.Empty
        };
    }
}
