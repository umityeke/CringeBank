using System;
using System.Linq;
using CringeBank.Domain.Auth.Enums;
using CringeBank.Domain.ValueObjects;

namespace CringeBank.Domain.Auth.Entities;

public sealed partial class AuthUser
{
    public static AuthUser Create(EmailAddress email, Username username, string authProvider = "sql")
    {
        ArgumentNullException.ThrowIfNull(email);
        ArgumentNullException.ThrowIfNull(username);

        var utcNow = DateTime.UtcNow;

        var user = new AuthUser
        {
            PublicId = Guid.NewGuid(),
            AuthProvider = string.IsNullOrWhiteSpace(authProvider) ? "sql" : authProvider,
            Status = AuthUserStatus.Active,
            CreatedAt = utcNow,
            UpdatedAt = utcNow
        };

        user.SetEmail(email);
        user.SetUsername(username);

        return user;
    }

    public void SetEmail(EmailAddress email)
    {
        ArgumentNullException.ThrowIfNull(email);

        Email = email.Value;
        EmailNormalized = email.Normalized;
        Touch();
    }

    public void SetUsername(Username username)
    {
        ArgumentNullException.ThrowIfNull(username);

        Username = username.Value;
        UsernameNormalized = username.Normalized;
        Touch();
    }

    public void Touch(DateTime? utcNow = null)
    {
        UpdatedAt = (utcNow ?? DateTime.UtcNow).ToUniversalTime();
    }

    public void MarkSignedIn(DateTime utcNow)
    {
        LastLoginAt = utcNow.ToUniversalTime();
        Touch(utcNow);
    }

    public void UpdateProfile(
        DisplayName displayName,
        ProfileBio bio,
        WebsiteUrl website,
        string? avatarUrl,
        string? bannerUrl,
        string? location)
    {
        ArgumentNullException.ThrowIfNull(displayName);
        ArgumentNullException.ThrowIfNull(bio);
        ArgumentNullException.ThrowIfNull(website);

        var verified = Profile?.Verified ?? false;

        if (Profile is null)
        {
            Profile = AuthUserProfile.Create(
                Id,
                displayName,
                bio,
                website,
                avatarUrl,
                bannerUrl,
                verified,
                location);
        }
        else
        {
            Profile.Update(displayName, bio, website, avatarUrl, bannerUrl, verified, location);
        }

        Touch();
    }

    public bool SetStatus(AuthUserStatus status)
    {
        if (Status == status)
        {
            return false;
        }

        Status = status;
        Touch();
        return true;
    }

    public bool Activate() => SetStatus(AuthUserStatus.Active);

    public bool Suspend() => SetStatus(AuthUserStatus.Suspended);

    public bool Ban() => SetStatus(AuthUserStatus.Banned);

    public bool AssignRole(AuthRole role)
    {
        ArgumentNullException.ThrowIfNull(role);

        if (_userRoles.Any(userRole => userRole.RoleId == role.Id))
        {
            return false;
        }

        var link = AuthUserRole.Create(Id, role.Id);
        _userRoles.Add(link);
        Touch();
        return true;
    }

    public bool RemoveRole(AuthRole role)
    {
        ArgumentNullException.ThrowIfNull(role);

        var existing = _userRoles.FirstOrDefault(userRole => userRole.RoleId == role.Id);

        if (existing is null)
        {
            return false;
        }

        _userRoles.Remove(existing);
        Touch();
        return true;
    }

    public bool HasRole(string roleName)
    {
        if (string.IsNullOrWhiteSpace(roleName))
        {
            return false;
        }

        var normalized = roleName.Trim().ToLowerInvariant();
        return _userRoles.Any(userRole => userRole.Role is not null &&
            string.Equals(userRole.Role.Name, normalized, StringComparison.OrdinalIgnoreCase));
    }
}
