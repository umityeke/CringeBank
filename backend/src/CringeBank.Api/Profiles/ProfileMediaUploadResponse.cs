using System;

namespace CringeBank.Api.Profiles;

public sealed record ProfileMediaUploadResponse(
    Uri UploadUrl,
    Uri ResourceUrl,
    DateTimeOffset ExpiresAtUtc,
    string BlobName,
    string ContentType);
