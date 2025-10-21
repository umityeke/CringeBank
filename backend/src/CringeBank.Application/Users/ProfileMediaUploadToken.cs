using System;

namespace CringeBank.Application.Users;

public sealed record ProfileMediaUploadToken(
    Uri UploadUri,
    Uri ResourceUri,
    DateTimeOffset ExpiresAtUtc,
    string BlobName,
    string ContentType);
