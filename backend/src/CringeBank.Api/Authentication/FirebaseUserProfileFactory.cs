using System;
using System.Globalization;
using System.Security.Claims;
using CringeBank.Application.Users;
using CringeBank.Domain.Enums;
using Microsoft.Extensions.Options;

namespace CringeBank.Api.Authentication;

public sealed class FirebaseUserProfileFactory
{
    private readonly FirebaseAuthenticationOptions _options;

    public FirebaseUserProfileFactory(IOptions<FirebaseAuthenticationOptions> options)
    {
        ArgumentNullException.ThrowIfNull(options);
        _options = options.Value;
    }

    public FirebaseUserProfile Create(ClaimsPrincipal principal)
    {
        ArgumentNullException.ThrowIfNull(principal);

        var firebaseUid = FindFirstValue(principal, "firebase_uid")
            ?? FindFirstValue(principal, "user_id")
            ?? throw new InvalidOperationException("Firebase UID claim bulunamadı.");

        var email = FindFirstValue(principal, ClaimTypes.Email)
            ?? FindFirstValue(principal, "email")
            ?? throw new InvalidOperationException("Email claim bulunamadı.");

        var emailVerified = GetBooleanClaim(principal, "email_verified", fallback: true);
        var claimsVersion = GetIntClaim(principal, "claims_version", _options.MinimumClaimsVersion);
        var displayName = FindFirstValue(principal, ClaimTypes.Name) ?? FindFirstValue(principal, "name");
        var profileImageUrl = FindFirstValue(principal, "picture");
        var phoneNumber = FindFirstValue(principal, "phone_number");
        var lastLoginAtUtc = GetTimestampClaim(principal, "auth_time");
        var lastSeenAppVersion = FindFirstValue(principal, "app_version");
        var isDisabled = GetBooleanClaim(principal, "disabled");
        var disabledAtUtc = GetTimestampClaim(principal, "disabled_at");
        var deletedAtUtc = GetTimestampClaim(principal, "deleted_at");
        var status = GetUserStatus(principal, isDisabled, deletedAtUtc);

        return new FirebaseUserProfile(
            firebaseUid,
            email,
            emailVerified,
            claimsVersion,
            displayName,
            profileImageUrl,
            phoneNumber,
            lastLoginAtUtc,
            lastSeenAppVersion,
            isDisabled,
            disabledAtUtc,
            deletedAtUtc,
            status);
    }

    private static string? FindFirstValue(ClaimsPrincipal principal, string claimType)
        => principal.FindFirst(claimType)?.Value;

    private static bool GetBooleanClaim(ClaimsPrincipal principal, string claimType, bool fallback = false)
    {
        var value = FindFirstValue(principal, claimType);
        if (string.IsNullOrWhiteSpace(value))
        {
            return fallback;
        }

        return bool.TryParse(value, out var parsed) ? parsed : fallback;
    }

    private static int GetIntClaim(ClaimsPrincipal principal, string claimType, int fallback)
    {
        var value = FindFirstValue(principal, claimType);
        if (string.IsNullOrWhiteSpace(value))
        {
            return fallback;
        }

        return int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed)
            ? parsed
            : fallback;
    }

    private static DateTimeOffset? GetTimestampClaim(ClaimsPrincipal principal, string claimType)
    {
        var value = FindFirstValue(principal, claimType);
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        if (long.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var seconds))
        {
            return DateTimeOffset.FromUnixTimeSeconds(seconds);
        }

        if (DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var parsed))
        {
            return parsed.ToUniversalTime();
        }

        return null;
    }

    private static UserStatus GetUserStatus(ClaimsPrincipal principal, bool isDisabled, DateTimeOffset? deletedAtUtc)
    {
        var value = FindFirstValue(principal, "user_status");

        if (!string.IsNullOrWhiteSpace(value) && Enum.TryParse<UserStatus>(value, true, out var parsed))
        {
            return parsed;
        }

        if (deletedAtUtc.HasValue)
        {
            return UserStatus.Deleted;
        }

        if (isDisabled)
        {
            return UserStatus.Disabled;
        }

        return UserStatus.Active;
    }
}
