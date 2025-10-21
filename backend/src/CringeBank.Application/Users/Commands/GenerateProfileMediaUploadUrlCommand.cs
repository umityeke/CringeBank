using System;
using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Users.Commands;

public sealed record GenerateProfileMediaUploadUrlCommand(
    Guid PublicId,
    ProfileMediaType MediaType,
    string ContentType) : ICommand<GenerateProfileMediaUploadUrlResult>;
