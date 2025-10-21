namespace CringeBank.Api.Profiles;

public sealed record GenerateProfileMediaUploadUrlRequest(
    string ContentType,
    string MediaType);
