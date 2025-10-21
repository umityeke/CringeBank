using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Auth;
using CringeBank.Application.Users.Queries;
using CringeBank.Domain.Auth.Enums;
using CringeBank.Domain.ValueObjects;

namespace CringeBank.Application.Users.Commands;

public sealed class UpdateAuthUserProfileCommandHandler : ICommandHandler<UpdateAuthUserProfileCommand, UpdateAuthUserProfileResult>
{
    private readonly IAuthUserRepository _authUserRepository;
    private readonly IUserReadRepository _userReadRepository;

    public UpdateAuthUserProfileCommandHandler(IAuthUserRepository authUserRepository, IUserReadRepository userReadRepository)
    {
        _authUserRepository = authUserRepository ?? throw new ArgumentNullException(nameof(authUserRepository));
        _userReadRepository = userReadRepository ?? throw new ArgumentNullException(nameof(userReadRepository));
    }

    public async Task<UpdateAuthUserProfileResult> HandleAsync(UpdateAuthUserProfileCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        var user = await _authUserRepository.GetByPublicIdAsync(command.PublicId, cancellationToken);

        if (user is null)
        {
            return UpdateAuthUserProfileResult.Failure("user_not_found");
        }

        if (user.Status is AuthUserStatus.Suspended or AuthUserStatus.Banned)
        {
            return UpdateAuthUserProfileResult.Failure("user_not_active");
        }

        var displayName = DisplayName.Create(command.DisplayName);
        var bio = ProfileBio.Create(command.Bio);
        var website = WebsiteUrl.Create(command.Website);
        var avatarUrl = NormalizeUrl(command.AvatarUrl);
        var bannerUrl = NormalizeUrl(command.BannerUrl);
        var location = NormalizeLocation(command.Location);

        user.UpdateProfile(displayName, bio, website, avatarUrl, bannerUrl, location);

        await _authUserRepository.SaveChangesAsync(cancellationToken);

        var profile = await _userReadRepository.GetProfileByPublicIdAsync(user.PublicId, cancellationToken);

        if (profile is null)
        {
            return UpdateAuthUserProfileResult.Failure("profile_not_found");
        }

        return UpdateAuthUserProfileResult.SuccessResult(profile);
    }

    private static string? NormalizeUrl(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        return trimmed.Length == 0 ? null : trimmed;
    }

    private static string? NormalizeLocation(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        return trimmed.Length == 0 ? null : trimmed;
    }
}
