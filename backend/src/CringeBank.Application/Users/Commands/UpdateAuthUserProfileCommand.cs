using System;
using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Users.Commands;

public sealed record UpdateAuthUserProfileCommand(
    Guid PublicId,
    string? DisplayName,
    string? Bio,
    string? Website,
    string? AvatarUrl,
    string? BannerUrl,
    string? Location) : ICommand<UpdateAuthUserProfileResult>;
